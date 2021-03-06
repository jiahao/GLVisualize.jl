function visualize_default(grid::Union{Texture{Float32, 2}, Matrix{Float32}}, s::Style, kw_args=Dict())
    grid_min    = get(kw_args, :grid_min, Vec2f0(-1, -1))
    grid_max    = get(kw_args, :grid_max, Vec2f0( 1,  1))
    grid_length = grid_max - grid_min
    scale = Vec3f0((1f0 / Vec2f0(size(grid))), 1f0) .* Vec3f0(grid_length, 1f0)
    p = GLNormalMesh(AABB{Float32}(Vec3f0(0), Vec3f0(1.0)))
    c = default(Vector{RGBA},s)
    n = Vec2f0(minimum(grid), maximum(grid))
    return Dict(
        :primitive  => p,
        :color      => c,
        :grid_min   => grid_min,
        :grid_max   => grid_max,
        :scale      => scale,
        :color_norm => n
    )
end
@visualize_gen Matrix{Float32} Texture Style

function visualize(grid::Texture{Float32, 2}, s::Style, customizations=visualize_default(grid, s))
    @materialize! color, primitive = customizations
    @materialize grid_min, grid_max, color_norm = customizations
    data = merge(Dict(
        :y_scale => grid,
        :color   => Texture(color),
    ), collect_for_gl(primitive), customizations)
    assemble_instanced(
        grid, data,
        "util.vert", "meshgrid.vert", "standard.frag",
        boundingbox=const_lift(particle_grid_bb, grid_min, grid_max, color_norm)
    )
end
