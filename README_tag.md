Description:
  This tag is the latest attempt at integrating Symbolic QED from Stanford into BlackParrot.
  SQED uses the approach of post-silicon quick error detection to formally prove that there
    are no timing bugs within some bounded model of execution. 

Latest update:
 This integration was attempted at POSH 1/18 and successfully achieved error injection for 
   arithmetic instructions.

Problems preventing integration:
  The nature of hacking together projects with a tight deadline led to this integration not being of 
    sufficent quality to integrate. There were also concerns about whether the tool was being
    properly integrated e.g. are there no errors because we are not looking hard enough or because
    the tool is not actually verifying the implementation properly.

Next tasks:
  Update the black-parrot implementation to the latest version
  Clean up qed implementation or link to stanford github repo
  Prove (through error injection or otherwise) that formal verification is valid
  Formal verification of control flow and memory in addition to arithmetic instructions

Additional info:
  https://github.com/upscale-project/black-parrot-sqed

