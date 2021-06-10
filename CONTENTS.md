# Marc's Arduino Stuff

This is grouped into general purpose libraries, and code for specific
boards.

Code within this filesystem is expected to be built uning Marc's
[Duinobuilder](file:./md_README.html) makefile.

If you prefer to use the Arduino IDE, you will need to convert the
files containing the main() functions in the board-specific project
directories into more normal sketch files.

It should be obvious which parts go into setup() and which belong in
loop().  You should remove the init() function call as this is done
for you by the sketches *real* main() function, which calls your
setup() and loop() functions.


## Libraries

* [Deferal](file:./md_libraries_Deferal_README.html) (Deferal class)

* RFM69Network

* Message 

* Routing (RoutingEntry and RoutingTable classes)

* SerialHandler (SerialHandlerClass class)



## Board-Specific Code

### Arduino Pro Mini

* [sensor]


