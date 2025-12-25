# MIPS atan2 Implementation

MIPS implementation of atan2 using a reduced lookup table (LUT) with linear 
interpolation (LERP). Credits to https://www.coranac.com/documents/arctangent/ 
for describing the algorithm.

## Features
- Computed entirely with integer arithmetic (no floating-point operations)
- As a result, it is highly performant for embedded systems and MIPS-based platforms
- Uses Q12/Q15 fixed-point arithmetic for intermediate calculations
- 129-entry reduced lookup table with linear interpolation

## Accuracy
- **Computational accuracy**: ~0.02 degrees (internal Q15 precision)
- **Output resolution**: Integer degrees [0, 359] (±0.5° rounding error)

**Note**: To retain higher precision, modify the output conversion. For example:
- For tenths of degrees (0-3599): `result = (Q15_value * 450) >> 15`
- For BRAD format (0-65535): Keep the Q15 value and scale appropriately

## Usage
See function header for input/output specifications.
