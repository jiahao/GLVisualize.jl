# Splits a dictionary in two dicts, via a condition
function Base.split(condition::Function, associative::Associative)
    A = similar(associative)
    B = similar(associative)
    for (key, value) in associative
        if condition(key, value)
            A[key] = value
        else
            B[key] = value
        end
    end
    A, B
end

#creates methods to accept signals, which then gets transfert to an OpenGL target type
macro visualize_gen(input, target, S)
    esc(quote
        visualize(value::$input, s::$S, customizations=visualize_default(value, s)) =
            visualize($target(value), s, customizations)

        function visualize(signal::Signal{$input}, s::$S, customizations=visualize_default(signal.value, s))
            tex = $target(signal.value)
            preserve(const_lift(update!, Signal(tex), signal))
            visualize(tex, s, customizations)
        end
    end)
end


# scalars can be uploaded directly to gpu, but not arrays
texture_or_scalar(x) = x
texture_or_scalar(x::Array) = Texture(x)
function texture_or_scalar{A <: Array}(x::Signal{A})
    tex = Texture(x.value)
    preserve(const_lift(update!, tex, x))
    tex
end

isnotempty(x) = !isempty(x)
AND(a,b) = a&&b
OR(a,b) = a||b
export OR


function GLVisualizeShader(shaders...; attributes...)
    shaders = map(shader -> load(joinpath(shaderdir(), shader)), shaders)
    TemplateProgram(shaders...;
        attributes...,  fragdatalocation=[(0, "fragment_color"), (1, "fragment_groupid")],
        updatewhile=ROOT_SCREEN.inputs[:open], update_interval=1.0
    )
end


function assemble_std(main, dict, shaders...; boundingbox=default_boundingbox(main, get(dict, :model, eye(Mat{4,4,Float32}))), primitive=GL_TRIANGLES)
    program = GLVisualizeShader(shaders..., attributes=dict)
    std_renderobject(dict, program, boundingbox, primitive, main)
end

function assemble_instanced(main, dict, shaders...; boundingbox=default_boundingbox(main, get(dict, :model, eye(Mat{4,4,Float32}))), primitive=GL_TRIANGLES)
    program = GLVisualizeShader(shaders..., attributes=dict)
    instanced_renderobject(dict, program, boundingbox, primitive, main)
end



function y_partition(area, percent)
    amount = percent / 100.0
    p = const_lift(area) do r
        (SimpleRectangle{Int}(r.x, r.y, r.w, round(Int, r.h*amount)),
            SimpleRectangle{Int}(r.x, round(Int, r.h*amount), r.w, round(Int, r.h*(1-amount))))
    end
    return const_lift(first, p), const_lift(last, p)
end
function x_partition(area, percent)
    amount = percent / 100.0
    p = const_lift(area) do r
        (SimpleRectangle{Int}(r.x, r.y, round(Int, r.w*amount), r.h ),
            SimpleRectangle{Int}(round(Int, r.w*amount), r.y, round(Int, r.w*(1-amount)), r.h))
    end
    return const_lift(first, p), const_lift(last, p)
end


glboundingbox(mini, maxi) = AABB{Float32}(Vec3f0(mini), Vec3f0(maxi)-Vec3f0(mini))
function default_boundingbox(main, model)
    main == nothing && return Signal(AABB{Float32}(Vec3f0(0), Vec3f0(1)))
    const_lift(*, model, AABB{Float32}(main))
end
call(::Type{AABB}, a::GPUArray) = AABB{Float32}(gpu_data(a))
call{T}(::Type{AABB{T}}, a::GPUArray) = AABB{T}(gpu_data(a))

call(::Type{AABB}, a::GPUArray) = AABB(gpu_data(a))
call(::Type{AABB}, a::GPUArray) = AABB(gpu_data(a))
Base.call{T, T2, T3}(::Type{AABB{T}}, positions::Texture{Point{3, T2}, 1}, scale::Texture{Vec{3, T3}, 1}, primitive_bb) = AABB{T}(gpu_data(positions), gpu_data(scale), primitive_bb)
Base.call{T, T2, T3}(::Type{AABB{T}}, positions::Texture{Point{3, T2}, 1}, scale::Vec{3, T3}, primitive_bb) = AABB{T}(gpu_data(positions), scale, primitive_bb)

function Base.call{T, T2, T3}(::Type{AABB{T}}, positions::Vector{Point{3, T2}}, scale::Vec{3, T3}, primitive_bb)
    primitive_scaled_min = minimum(primitive_bb) .* scale
    primitive_scaled_max = maximum(primitive_bb) .* scale
    pmax = max(primitive_scaled_min, primitive_scaled_max)
    pmin = min(primitive_scaled_min, primitive_scaled_max)
    main_bb = AABB{T}(positions)
    glboundingbox(minimum(main_bb) + pmin, maximum(main_bb) + pmax)
end
function Base.call{T, T2, T3}(::Type{AABB{T}}, positions::Vector{Point{3, T2}}, scale::Vector{Vec{3, T3}}, primitive_bb)
    _max = Vec{3, T}(typemin(T))
    _min = Vec{3, T}(typemax(T))
    for (p, s) in zip(positions, scale)
        p = Vec{3, T}(p) 
        s_min = Vec{3, T}(s) .* minimum(primitive_bb)
        s_max = Vec{3, T}(s) .* maximum(primitive_bb)
        s_min_r = min(s_min, s_max)
        s_max_r = max(s_min, s_max)
        _min = min(_min, p + s_min_r)
        _max = max(_max, p + s_max_r)
    end
    glboundingbox(_min, _max)
end
particle_grid_bb{T}(min_xy::Vec{2,T}, max_xy::Vec{2,T}, minmax_z::Vec{2,T}) = glboundingbox(Vec(min_xy..., minmax_z[1]), Vec(max_xy..., minmax_z[2]))

@enum MouseButton MOUSE_LEFT MOUSE_MIDDLE MOUSE_RIGHT

"""
Returns two signals, one boolean signal if clicked over `robj` and another 
one that consists of the object clicked on and another argument indicating that it's the first click
"""
function clicked(robj::RenderObject, button::MouseButton, window::Screen)
    @materialize mouse_hover, mousebuttonspressed = window.inputs
    leftclicked = const_lift(mouse_hover, mousebuttonspressed) do mh, mbp
        mh[1] == robj.id && mbp == Int[button]
    end
    clicked_on_obj = keepwhen(leftclicked, false, leftclicked)
    clicked_on_obj = const_lift((mh, x)->(x,robj,mh), mouse_hover, leftclicked)
    leftclicked, clicked_on_obj
end

"""
Returns a boolean signal indicating if the mouse hovers over `robj`
"""
is_hovering(robj::RenderObject, window::Screen) = const_lift(window.inputs[:mouse_hover]) do mh
    mh[1] == robj.id
end


"""
Returns a signal with the difference from dragstart and current mouse position, 
and the index from the current ROBJ id.
"""
function dragged_on(robj::RenderObject, button::MouseButton, window::Screen)
    @materialize mouse_hover, mousebuttonspressed, mouseposition = window.inputs
    start_value = (Vec2f0(0), mouse_hover.value[2], false, Vec2f0(0))
    tmp_signal = foldl(start_value, mouse_hover, mousebuttonspressed, mouseposition) do past, mh, mbp, mpos
        diff, dragstart_index, was_clicked, dragstart_pos = past
        over_obj = mh[1] == robj.id
        is_clicked = mbp == Int[button]
        if is_clicked && was_clicked # is draggin'
            return (dragstart_pos-mpos, dragstart_index, true, dragstart_pos)
        elseif over_obj && is_clicked && !was_clicked # drag started
            return (Vec2f0(0), mh[2], true, mpos)
        end
        return start_value
    end
    const_lift(getindex, tmp_signal, 1:2)
end

points2f0{T}(positions::Vector{T}, range::Range) = Point2f0[Point2f0(range[i], positions[i]) for i=1:length(range)]
