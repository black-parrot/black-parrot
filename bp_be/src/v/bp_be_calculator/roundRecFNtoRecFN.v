

module
    roundRecFNtoRecFN#(
        parameter inExpWidth = 3,
        parameter inSigWidth = 3,
        parameter roundExpWidth = 3,
        parameter roundSigWidth = 3,
        parameter outExpWidth = 3,
        parameter outSigWidth = 3
    ) (
        input [(`floatControlWidth - 1):0] control,
        input [(inExpWidth + inSigWidth):0] in,
        input [2:0] roundingMode,
        output [(outExpWidth + outSigWidth):0] out,
        output [4:0] exceptionFlags
    );

  // synopsys translate_off
  if ((roundExpWidth > inExpWidth) || (roundSigWidth > inSigWidth))
    $error("Intermediate rounding must be smaller than input");

  if ((roundExpWidth > outExpWidth) || (roundSigWidth > outSigWidth))
    $error("Intermediate rounding must be smaller than output");
  // synopsys translate_on

  // Round the input to the intermediate precision
  wire [roundExpWidth+roundSigWidth:0] round;
  recFNToRecFN#(
    inExpWidth,
    inSigWidth,
    roundExpWidth,
    roundSigWidth
  ) doRound (
    control,
    in,
    roundingMode,
    round,
    exceptionFlags
  );

  // Deconstruct the rounded result
  wire isNaN, isInf, isZero, sign;
  wire signed [(roundExpWidth + 1):0] sExpRound;
  wire [roundSigWidth:0] sigRound;
  recFNToRawFN#(roundExpWidth, roundSigWidth)
    roundToRawIn(round, isNaN, isInf, isZero, sign, sExpRound, sigRound);

  //
  // Unsafe upconvert (Made safe because we've already rounded)
  //
  localparam biasAdj = (1 << inExpWidth) - (1 << roundExpWidth);
  wire [outExpWidth:0] nanExp = {outExpWidth+1{1'b1}};
  wire [outExpWidth:0] infExp = 2'b11 << (outExpWidth-1);
  wire [outExpWidth:0] zeroExp = {outExpWidth+1{1'b0}};

  wire outSign = sign;
  wire [outExpWidth:0] outExp = isNaN ? nanExp : isInf ? infExp : isZero ? zeroExp : (sExpRound + biasAdj);
  wire [outSigWidth-2:0] outFract = sigRound << (outSigWidth - roundSigWidth);

  assign out = {sign, outExp, outFract};

endmodule

