# Froggotten Recipes - PlayJam Version

![Game Title Card showing Froggo and Magic Cocktails](source/images/titlecard_itch.png?raw=true)

Froggotten Recipes is a smol [Playdate](https://play.date) game made by a group of friends for a game jam ([PlayJam5](https://itch.io/jam/playjam-5)).

 Theme was: You Forgot Something


We took an extra weekend after the jam to develop it a 'lil further which was - of course - a total trap.  
We've ended up with a totally new version and (maybe) learned something about feature creep.

## Jam Version
This git branch has the game's [source files for the jam with a few fixes](https://github.com/britalmeida/project_loose/tree/jam_version) as well as the 
[original source files as it was submitted for the jam](https://github.com/britalmeida/project_loose/tree/playjam5).  
**To play the improved jam version**, see the [itch.io page](https://iralmeida.itch.io/froggotten-recipes-jam).

## Full Game Version
**To play the totally new version** with new mechanics, art, soundfx, sleep, and an equally grumpy frog, see the [new itch.io page](https://iralmeida.itch.io/froggotten-recipes) (and who knows maybe the playdate catalog one day!).  
For the sources, see [git's main branch](https://github.com/britalmeida/project_loose/tree/main).



## Dev Setup

Either **manually** run the `pdc` compiler and the simulator, or use **VSCode** as interface for git, code and launching the simulator.

1. **Download the PlaydateSDK** to run the simulator and the compiler.  
https://play.date/dev/

2. **Set environment variables**

    (Optional) to run the compiler from the terminal

    e.g. on `~/.bashrc`:
    ```
    # Playdate
    export PLAYDATE_SDK_PATH="$HOME/stuff/PlaydateSDK"
    export PATH="$PLAYDATE_SDK_PATH/bin:$PATH"
    ```

3. **Setup VSCode**

    - Install **VSCode extensions**
        - Playdate (`midouest.playdate-debug`) - package the game and run in the simulator from the IDE.
        - Lua (`sumneko.lua`) - syntax highlighting and language support for Lua.

    - Add the SDK Path to the settings in the `.code-workspace` file
        ```
        "settings": {
            "playdate-debug.sdkPath": "/Users/stuff/PlaydateSDK",
        }
        ```

4. **Workflow**

    Open the project folder in VSCode.  
    Press F5, the playdate simulator should appear.  
    From the simulator, the game can be uploaded to a physical console.
 