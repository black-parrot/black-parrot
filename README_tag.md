Description: This tag is the latest attempt at integrating BlackParrot into OpenPiton. See ![System
Diagram](system_diagram.png) for a pictorial description of the integration. Essentially, the idea
is to have BP as an OpenPiton tile and leverage their coherence scheme for inter-processor
coherence, while maintaining local coherence within a processor between cores using the LCE/CCE
scheme. The OpenPiton caches need only send invalidates to the CCEs which they control, using a
hierarchical coherence scheme.

Latest update: This integration was attempted at POSH 7/14 and did not successfully boot BlackParrot
within the OpenPiton infrastructure. However, the basic skeleton of integration was written and is
ready for expansion.

Problems preventing integration: Mostly time constraints.  An inordinate amount of time was spent
gluing together the build infrastructures of OP and BP. The bootstrapping sequence of BP currently
requires an independent host module, which we attempted to incorporate into the tile.

Next tasks: Update black-parrot to latest and debug the bootstrapping sequence.  Once messages are
flowing into the OP L1.5, modify OP to support hierarchical invalidations.

