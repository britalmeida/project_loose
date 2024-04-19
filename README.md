# ???

*Game submission for the [PlayJam5](https://itch.io/jam/playjam-5)!*

Theme was: ???


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

    - Add the SDK Path to the settings in the `.code-workspace` file
        ```
        "settings": {
            "playdate-debug.sdkPath": "/Users/stuff/PlaydateSDK",
        }
        ```

    - Install **VSCode extensions**
        - Playdate (`midouest.playdate-debug`) - package the game and run in the simulator from the IDE.
        - Lua (`sumneko.lua`) - syntax highlighting and language support for Lua.

    Open the project folder in VSCode. Press F5. Go!
 