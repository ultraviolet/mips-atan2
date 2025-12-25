# Arctangens LUT. Interval: [0, 1] (one=128); PI=0x20000
atan_table:
    .half 0x0000,0x0146,0x028C,0x03D2,0x0517,0x065D,0x07A2,0x08E7
    .half 0x0A2C,0x0B71,0x0CB5,0x0DF9,0x0F3C,0x107F,0x11C1,0x1303
    .half 0x1444,0x1585,0x16C5,0x1804,0x1943,0x1A80,0x1BBD,0x1CFA
    .half 0x1E35,0x1F6F,0x20A9,0x21E1,0x2319,0x2450,0x2585,0x26BA
    .half 0x27ED,0x291F,0x2A50,0x2B80,0x2CAF,0x2DDC,0x2F08,0x3033
    .half 0x315D,0x3285,0x33AC,0x34D2,0x35F6,0x3719,0x383A,0x395A
    .half 0x3A78,0x3B95,0x3CB1,0x3DCB,0x3EE4,0x3FFB,0x4110,0x4224
    .half 0x4336,0x4447,0x4556,0x4664,0x4770,0x487A,0x4983,0x4A8B
	# 64
    .half 0x4B90,0x4C94,0x4D96,0x4E97,0x4F96,0x5093,0x518F,0x5289
    .half 0x5382,0x5478,0x556E,0x5661,0x5753,0x5843,0x5932,0x5A1E
    .half 0x5B0A,0x5BF3,0x5CDB,0x5DC1,0x5EA6,0x5F89,0x606A,0x614A
    .half 0x6228,0x6305,0x63E0,0x64B9,0x6591,0x6667,0x673B,0x680E
    .half 0x68E0,0x69B0,0x6A7E,0x6B4B,0x6C16,0x6CDF,0x6DA8,0x6E6E
    .half 0x6F33,0x6FF7,0x70B9,0x717A,0x7239,0x72F6,0x73B3,0x746D
    .half 0x7527,0x75DF,0x7695,0x774A,0x77FE,0x78B0,0x7961,0x7A10
    .half 0x7ABF,0x7B6B,0x7C17,0x7CC1,0x7D6A,0x7E11,0x7EB7,0x7F5C
	# 128
    .half 0x8000,0x80A2

# atan2 - compute arctangent of y/x in degrees, using only integer registers
# inputs: $a0 (x, signed), $a1 (y, signed)
# output: $v0 (angle in degrees, 0-359)
# no registers are preserved, must caller save. $t0-$t9 are clobbered. 

atan2:
	# handle trivial cases when y=0 or x=0 (basically just straight cardinal dir)
	# if(y==0)	return (x>=0 ? 0 : BRAD_PI); (brad_pi is just 180)
	bne $a1, $zero, atan2_tcase1
	slt $t0, $a0, $zero

	# if x is negative then return 180, otherwise return 0
	bne $t0, $zero, atan2_return_180 
	li $v0, 0
	jr $ra
atan2_return_180:
	li $v0, 180
	jr $ra

atan2_tcase1:
	# if x=0, angle is 90 or 270
	bne $a0, $zero, atan2_nontrivial
	slt $t0, $a1, $zero
	# if y is negative then return 270, otherwise return 90
	bne $t0, $zero, atan2_return_270
	li $v0, 90
	jr $ra
atan2_return_270:
	li $v0, 270
	jr $ra

atan2_nontrivial:
	# through a series of symmetries, we can reduce the space to a single octant (defined as OCTANIFY)
	li $t9, 0 # octant
	move $t0, $a0 # x
	move $t1, $a1 # y
	
	# if(_y<  0)	{			 _x= -_x;   _y= -_y; _o += 4; }	
	# atan2_o1 (x,y) to (-x,-y)
	slt $t2, $t1, $zero
	beq $t2, $zero, atan2_o2
	sub $t0, $zero, $t0
	sub $t1, $zero, $t1
	addi $t9, $t9, 4
atan2_o2:
	# if(_x<= 0)	{ _t= _x;    _x=  _y;   _y= -_t; _o += 2; }
	# (x,y) to (y,-x)
	slt $t2, $zero, $t0
	bne $t2, $zero, atan2_o3
	move $t2, $t0
	move $t0, $t1
	sub $t1, $zero, $t2
	addi $t9, $t9, 2 # 2*45 = 90
atan2_o3:
	# if(_x<=_y)	{ _t= _y-_x; _x= _x+_y; _y=  _t; _o += 1; }
	# (x,y) to (x+y, y-x)
	slt $t2, $t1, $t0
	bne $t2, $zero, atan2_o_done
	sub $t2, $t1, $t0
	add $t0, $t0, $t1
	move $t1, $t2
	addi $t9, $t9, 1 # 1*45 = 45

# so now, 0 <= y <= x (so atan of y/x is within [0, 45])
atan2_o_done:
	# prevent /0
	beq $t0, $zero, atan2_dzero
	

	# t = (y << 12) / x (Q12 fixed point, range 0-4096 for t in [0,1])
	sll $t1, $t1, 12
	div $t1, $t0
	mflo $t1 # get quotient
	
	# if t = 4096 or potentially greater then this maps to the 129th table element which is out of bounds so we just map it to 128th aka 4095
	li $t2, 4096
	slt $t3, $t1, $t2
	bne $t3, $zero, atan2_t_isok
	li $t1, 4095
atan2_t_isok:

	# ATANLUT_STRIDE is 32
	# index = t >> 5 (get index between 0-127 using div by 32)
	# basically just t/ATANLUT_STRIDE
	srl $t2, $t1, 5
	# h = t & 0x1F (bitmask to get the lwr 5 bits to get the position between table entries for lerp)
	andi $t3, $t1, 0x1F
	
	# load lookup table
	la $t4, atan_table
	sll $t5, $t2, 1
	add $t4, $t4, $t5
	lhu $t5, 0($t4)      # fa= atanLUT[t/ATANLUT_STRIDE  ];
	lhu $t6, 2($t4)      # fb= atanLUT[t/ATANLUT_STRIDE+1];
	
	# ATANLUT_STRIDE_SHIFT is 5
	# LERP: result = fa + ((fb - fa) * h >> 5) in Q15 format
	sub $t6, $t6, $t5    # fb - fa
	mul $t6, $t6, $t3    # (fb - fa) * h
	sra $t6, $t6, 5      # >> 5
	add $t5, $t5, $t6    # fa + interpolation
	
	# dphi = result * 45 / 0x8000
	# = result * 45 >> 15
	li $t6, 45
	mul $t5, $t5, $t6
	sra $t5, $t5, 15
	# $t5 is (Q15_val * 45) >> 15
	
	# phi = octant * 45 + dphi
	# add in the previously calc'ed octant offset
	li $t6, 45
	mul $t6, $t9, $t6
	add $v0, $t6, $t5
	
	# normalize to range 0-359 in case result >= 360deg
	li $t6, 360
	slt $t7, $v0, $t6
	bne $t7, $zero, atan2_done
	sub $v0, $v0, $t6
atan2_done:
	jr $ra

# prevent div0 case
atan2_dzero:
	li $v0, 0
	jr $ra
