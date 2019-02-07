Description:

  This tag is the latest attempt at integrating BlackParrot with OpenPiton. The goal of this
    integration is to replace the cache coherence control of the ME with the OpenPiton cache 
    coherence system.  This would enable BlackParrot to communicate with other cores that are 
    supported by OpenPiton as well as provide a well-tested implementation of coherence to 
    reduce the testing space.

Latest update:

  This integration was attempted at POSH 1/18 and resulted in communication being done between 
    the two modules.  However the translation between the protocols is not done yet.

Next tasks:
  
  Adding support for other messages in cache coherence protocol.
  Full support coherence with regression tests using OpenPiton as the coherence controller.
  Support hierarchical cache coherence (oct-core BlackParrot as a single OpenPiton tile).
  Integration as a submodule to the OpenPiton project.


Additional info:

https://github.com/PrincetonUniversity/openpiton

