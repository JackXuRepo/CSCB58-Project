# Air Pong
CSCB58 Winter 2018 UTSC

By: Jason Fong, Jack Xu

## Acknowledgements
This project builds on code from:
* [https://github.com/felixmo/Pong](https://github.com/felixmo/Pong) (MIT License)
* [https://github.com/chiusin97525/Game-Console](https://github.com/chiusin97525/Game-Console) (unspecified, previous semester project)

See the "Licenses" folder for more information.

## Prerequisites
- Quartus 16.0 or newer
- Altera DE2 Board
- VGA Monitor

## Build instructions

### Method 1: Set up your own project in Quartus
1. Clone the repository
```
$ git clone https://github.com/jfong701/CSCB58-Project.git
```
2. Navigate to the "Air Pong" folder.
3. Set up new project in Quartus, set top-level module as AirPong.v
4. Choose the appropriate board and settings
5. Compile AirPong.v and push program to the board
6. Ensure board is connected to monitor

### Method 2: Open the existing project file
1. Navigate to Project Zips folder in the repository
2. Download the most recent .zip file
3. On your computer, extract the files from the zip, and place in a folder
4. Open the .qbf file with Quartus
5. In Quartus, open AirPong.v
6. Compile and push program to the board
7. Ensure board is connected to monitor

## Controls
| Control | Action        |
| --------| --------------|
| KEY3    | Player 1 Up   |
| KEY2    | Player 1 Down |
| KEY1    | Player 2 Up   |
| KEY0    | Player 2 Down |
| SW17    | Reset Game    |
| SW0     | Pause Game    |
