# GLVisualize

GLVisualize is an interactive 2D/3D visualization library completely written in OpenLG and Julia.

It is actively developped but it isn't officially released yet, since there are still quite a few 
inconsistencies and missing documentations.
A lot of things already work nicely, so besides missing documentations and a high probability that the API will change in the near future, there is no real reason why you shouldn't give it a try.
You can look at `test/runtests.jl` and the `example` folder, to get a sense of how you can use GLVisualize.

#Installation

Here is a script adding the packages and checking out the correct branches:

```Julia
Pkg.add("GLVisualize")
Pkg.checkout("Reactive")
Pkg.checkout("GLVisualize")
Pkg.checkout("GLAbstraction")
Pkg.checkout("GLWindow")
```


Known problems:

- On Mac OS, you need to make sure that Homebrew.jl works correctly, which was not the case on some tested machines (needed to checkout master and then rebuild)
- GLFW needs `cmake` and `xorg-dev` `libglu1-mesa-dev` on linux (can be installed via `sudo apt-get install xorg-dev libglu1-mesa-dev`).
- VideoIO and FreeType seem to be also problematic on some platforms. There isn't a fix for all situations. If these package fail, try `Pk.update();Pkg.build("FailedPackage")`.If this still fails, report an issue on Github!

Try `Pkg.test("GLVisualize")` to see if things work! If things are working, you should see (after some delay for compilation) an animation pop up in a window with a spiral of cubes moving over a background of several other images and visualizations. Something like this:
![](https://github.com/JuliaGL/GLVisualize.jl/blob/master/docs/testimage.png?raw=true)
Close the window when you tire of watching it, and you should see a "tests passed" message.
