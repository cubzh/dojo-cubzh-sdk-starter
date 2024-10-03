# Dojo Cubzh SDK Starter

<div align="center">
  <a href="https://app.cu.bzh/?script=github.com/cubzh/dojo-cubzh-sdk-starter">
    <img src="play_button.png" alt="Play Now" width="30%" height="30%">
  </a>
  <p></p>
  <img src="diamondpit.gif" alt="Play Now" width="100%" height="100%">
</div>

This repository contains a Lua file (`world.lua`) that is loaded by Cubzh when visiting [this link](https://app.cu.bzh/editions/dojo-1.0.0-alpha.12/?script=github.com/cubzh/dojo-cubzh-sdk-starter).

## Backend Setup with Dojo

1. Install Dojo version 1.0.0-alpha.12
   ```
   curl -L https://install.dojoengine.org | bash
   dojoup --version v1.0.0-alpha.12
   ```
2. Clone the Dojo starter repository:
   ```
   git clone https://github.com/dojoengine/dojo-starter
   ```
3. Run Katana locally on a new terminal (this is a local blockchain)
   ```
   katana --disable-fee --allowed-origins "*"
   ```
4. Build the project:
   ```
   sozo build
   ```
5. Comment out the `world_address` in `Scarb.toml`
6. Deploy the contracts on your local Katana:
   ```
   sozo migrate apply
   ```
7. Start Torii:
   ```
   torii --world 0x5d475a9221f6cbf1a016b12400a01b9a89935069aecd57e9876fcb2a7bb29da --allowed-origins "*"
   ```
8. Uncomment `world_address` in `Scarb.toml` and replace with the correct world address:
   ```
   world_address = "0x5d475a9221f6cbf1a016b12400a01b9a89935069aecd57e9876fcb2a7bb29da"
   ```

## Frontend Update (Cubzh)

1. Fork this repository
2. Your version of the game is now accessible at `https://app.cu.bzh/?script=github.com/<username>/<repo>:<commithash>`
3. Update the "Play" button URL in the README (replace with URL of your fork)
4. Visit your Github repository page and click "Play"
5. Make desired changes in `world.lua`
6. Push your changes and access your version at:
   ```
   https://app.cu.bzh/?script=github.com/<username>/<repo>:<commithash>
   ```
   Note: Include the commit hash to bypass the one-day cache.

## Code Explanation

The `world.lua` file contains the following key components:

1. Module Import: Imports the "dojo" module from a GitHub repository
2. World Configuration: Sets up game world parameters
3. Constants: Defines game constants like directions and avatar names
4. Global Variables: Declares entities and remaining moves
5. Dojo Functions: Implements functions to interact with the Dojo backend
6. Dojo Callbacks: Handles updates from the Dojo backend
7. Entity Management: Functions for creating and managing game entities
8. Cubzh Hooks: Defines the `Client.OnStart` function
9. Game Initialization: Sets up the game map, camera, and UI
10. Controls: Handles player movement inputs

For more detailed information about each component, please refer to the comments in the `world.lua` file.

## Getting Started

To run this project:

1. Follow the backend setup instructions above
2. Fork this repository
3. Update the README link in the play button to point to your forked repository
4. Visit the Cubzh link provided at the top of this README to play the game

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
