This program allows one (in conjunction with the MCON replacement CON driver) to run multiple DOS tasks concurrently, with one active task per screen.
To access the Session Manager screen simply strike ALT+F10 at any point. This will suspend the foreground app and swap to the Session Manager selection screen.
From there, you can strike the screen number for the task you wish to go to, thereby swapping to that screen and reawakening the task.
This is a demonstration program and provides a very basic multitasking environment to work in. All internal API endpoints used for communication between the Session Manager and MCON are considered reserved and no guarantee about their presence is made in any future iterations of SCP/DOS multitasking software.

To ensure SM works correctly, please make sure you add the line `DEVICE=MCON.SYS` (including an optional path to the driver file) to your `CONFIG.SYS` file on your boot drive and ensure you copy `MCON.SYS` to the location specified in the `DEVICE=` instruction. MCON.SYS can be found in the repository MCON.
Please only use executables found in the `bin` directories of the `main` branch.