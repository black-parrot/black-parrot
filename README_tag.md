Description: This tag is the latest attempt at converting the BlackParrot Back End into a bitserial
processor. Dan Petrisko thinks that this is a good idea based on no architectural analysis, but
instead because it is fun. 

Latest update: This was attempted over a weekend during EE477 at UW. It successfully achieved
bitserial execution, but had problems with control flow.

Problems preventing integration: Bitserial control flow is complicated enough that this is a
non-trivial task to debug. For instance, it is very difficult to detect what happens when an
instruction commits because the update comes over 64 cycles.

Next tasks: Complete the implementation, do some analysis to see if this is worth it at all. One
benefit would be that it will demonstrate how modular BlackParrot is (look at this crazily different
component switch-out!)

Additional info:
https://docs.google.com/presentation/d/15P8n1oprgaNuFO3OiGN_Z9prKWLTlf5Y5ZaWbcdUOtQ/edit 

