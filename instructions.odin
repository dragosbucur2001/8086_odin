package emulator

import "core:log"

//
// DEFINITIONS
//

BitGroup :: enum {
	NONE,
	LITERAL,
	D, // Direction To/From register
	W, // wide or not
	S, // sign extended
	MOD, // Register Mode, or Memory Mode w/ displacement
	REG, // register operand to be used
	RM, // register or memory "destination""
	DATA,
	DISP,
}
BG :: BitGroup

InstructionSection :: struct {
	group:     BG,
	bit_count: u8,
	value:     u8,
	implied:   bool,
}

OpCode :: enum {
	NONE,
	MOV,
	ADD,
	SUB,
	CMP,
	JNZ, // JNE
	JE, // JZ
	JL, // JNGE
	JLE, // JNG
	JB, // JNAE
	JBE, // JNA
	JP, // JPE
	JO,
	JS,
	JNL, // JGE
	JNLE, // JG
	JNB, // JAE
	JA, // JNBE
	JNP, // JPO
	JNO,
	JNS,
	LOOP,
	LOOPZ,
	LOOPNZ,
	JCXZ,
}

Instruction :: struct {
	type:     OpCode,
	sections: [10]InstructionSection,
}

ImmediateOperand :: distinct i16

DirectAddrOperand :: distinct i16

DisplacementWidth :: enum {
	BIT_0,
	BIT_8,
	BIT_16,
}

EffectiveAddrOperand :: struct {
	displacement: i16,
	disp_width:   DisplacementWidth,
	base:         u8, // rm field
}

EffectiveOperandBase := [8]string {
	"bx + si",
	"bx + di",
	"bp + si",
	"bp + di",
	"si",
	"di",
	"bp",
	"bx",
}

RegisterOperand :: struct {
	reg: u8,
}

RegisterName := [8][2]string {
	{"al", "ax"},
	{"cl", "cx"},
	{"dl", "dx"},
	{"bl", "bx"},
	{"ah", "sp"},
	{"ch", "bp"},
	{"dh", "si"},
	{"bh", "di"},
}

Operand :: union {
	ImmediateOperand,
	DirectAddrOperand,
	EffectiveAddrOperand,
	RegisterOperand,
}

InstrFlags :: enum {
	Wide,
}

DecodedInstruction :: struct {
	type:  OpCode,
	dst:   Operand,
	src:   Operand,
	flags: bit_set[InstrFlags],
}

//
// INITIALISATION & GLOBALS
//

BitGroupSizes := [BitGroup]u8 {
	BG.NONE    = 0,
	BG.LITERAL = 0,
	BG.D       = 1,
	BG.W       = 1,
	BG.S       = 1,
	BG.MOD     = 2,
	BG.REG     = 3,
	BG.RM      = 3,
	// DATA and DISP are 8 or 16 depending on MOD and W
	BG.DATA    = 0,
	BG.DISP    = 0,
}


OpCodeNames := [OpCode]string {
	.NONE   = "ERROR",
	.MOV    = "mov",
	.ADD    = "add",
	.SUB    = "sub",
	.CMP    = "cmp",
	.JNZ    = "jnz",
	.JE     = "je",
	.JL     = "jl",
	.JLE    = "jle",
	.JB     = "jb",
	.JBE    = "jbe",
	.JP     = "jp",
	.JO     = "jo",
	.JS     = "js",
	.JNL    = "jnl",
	.JNLE   = "jnle",
	.JNB    = "jnb",
	.JA     = "ja",
	.JNP    = "jnp",
	.JNO    = "jno",
	.JNS    = "jns",
	.LOOP   = "loop",
	.LOOPZ  = "loopz",
	.LOOPNZ = "loopnz",
	.JCXZ   = "jcxz",
}

@(private)
LiteralData :: struct {
	bit_count: u8,
	value:     u8,
}

@(private)
ImpliedBitGroup :: struct {
	bit_group: BG,
	value:     u8,
}

@(private)
InitSections :: union #no_nil {
	BG,
	LiteralData,
	ImpliedBitGroup,
}

init_instruction :: proc(type: OpCode, sections: ..InitSections) -> (result: Instruction) {
	result.type = type

	for section, idx in sections {
		switch unwrapped in section {
		case BG:
			{
				result.sections[idx] = InstructionSection {
					group     = unwrapped,
					bit_count = BitGroupSizes[unwrapped],
					value     = 0,
				}
			}
		case LiteralData:
			{
				assert(unwrapped.bit_count > 0 && unwrapped.bit_count <= 8)

				result.sections[idx] = InstructionSection {
					group     = BG.LITERAL,
					bit_count = unwrapped.bit_count,
					value     = unwrapped.value,
				}
			}
		case ImpliedBitGroup:
			{
				result.sections[idx] = InstructionSection {
					group     = unwrapped.bit_group,
					bit_count = BitGroupSizes[unwrapped.bit_group],
					value     = unwrapped.value,
					implied   = true,
				}
			}
		}
	}

	return result
}

DirAddr := [3]InitSections{}

Instructions := [?]Instruction {
	// reg/mem to/from register
	init_instruction(
		OpCode.MOV,
		LiteralData{6, 0b100010},
		BG.D,
		BG.W,
		BG.MOD,
		BG.REG,
		BG.RM,
		BG.DISP,
	),
	// immidiate to register/memory
	init_instruction(
		OpCode.MOV,
		LiteralData{7, 0b1100011},
		BG.W,
		BG.MOD,
		LiteralData{3, 0b000},
		BG.RM,
		BG.DISP,
		BG.DATA,
	),
	// immidiate to register
	init_instruction(OpCode.MOV, LiteralData{4, 0b1011}, BG.W, BG.REG, BG.DATA),
	// mem to acc
	init_instruction(
		OpCode.MOV,
		LiteralData{7, 0b1010000},
		BG.W,
		ImpliedBitGroup{BG.REG, 0},
		ImpliedBitGroup{BG.MOD, 0},
		ImpliedBitGroup{BG.RM, 0b110},
		BG.DISP,
		ImpliedBitGroup{BG.D, 1},
	),
	// acc to mem
	init_instruction(
		OpCode.MOV,
		LiteralData{7, 0b1010001},
		BG.W,
		ImpliedBitGroup{BG.REG, 0},
		ImpliedBitGroup{BG.MOD, 0},
		ImpliedBitGroup{BG.RM, 0b110},
		BG.DISP,
	),
	// reg/mem to register
	init_instruction(
		OpCode.ADD,
		LiteralData{6, 0b000000},
		BG.D,
		BG.W,
		BG.MOD,
		BG.REG,
		BG.RM,
		BG.DISP,
	),
	// imm to register/mem
	init_instruction(
		OpCode.ADD,
		LiteralData{6, 0b100000},
		BG.S,
		BG.W,
		BG.MOD,
		LiteralData{3, 0b000},
		BG.RM,
		BG.DISP,
		BG.DATA,
	),
	// imm to acc
	init_instruction(
		OpCode.ADD,
		LiteralData{7, 0b0000010},
		BG.W,
		ImpliedBitGroup{BG.MOD, 0b11},
		ImpliedBitGroup{BG.RM, 0b000},
		BG.DATA,
	),
	// reg/mem to register
	init_instruction(
		OpCode.SUB,
		LiteralData{6, 0b001010},
		BG.D,
		BG.W,
		BG.MOD,
		BG.REG,
		BG.RM,
		BG.DISP,
	),
	// imm to register/mem
	init_instruction(
		OpCode.SUB,
		LiteralData{6, 0b100000},
		BG.S,
		BG.W,
		BG.MOD,
		LiteralData{3, 0b101},
		BG.RM,
		BG.DISP,
		BG.DATA,
	),
	// imm to acc
	init_instruction(
		OpCode.SUB,
		LiteralData{7, 0b0010110},
		BG.W,
		ImpliedBitGroup{BG.MOD, 0b11},
		ImpliedBitGroup{BG.RM, 0b000},
		BG.DATA,
	),
	// reg/mem to register
	init_instruction(
		OpCode.CMP,
		LiteralData{6, 0b001110},
		BG.D,
		BG.W,
		BG.MOD,
		BG.REG,
		BG.RM,
		BG.DISP,
	),
	// imm to register/mem
	init_instruction(
		OpCode.CMP,
		LiteralData{6, 0b100000},
		BG.S,
		BG.W,
		BG.MOD,
		LiteralData{3, 0b111},
		BG.RM,
		BG.DISP,
		BG.DATA,
	),
	// imm to acc
	init_instruction(
		OpCode.CMP,
		LiteralData{7, 0b0011110},
		BG.W,
		ImpliedBitGroup{BG.MOD, 0b11},
		ImpliedBitGroup{BG.RM, 0b000},
		BG.DATA,
	),
	init_instruction(OpCode.JNZ, LiteralData{8, 0b01110101}, BG.DATA),
	init_instruction(OpCode.JE, LiteralData{8, 0b01110100}, BG.DATA),
	init_instruction(OpCode.JL, LiteralData{8, 0b01111100}, BG.DATA),
	init_instruction(OpCode.JLE, LiteralData{8, 0b01111110}, BG.DATA),
	init_instruction(OpCode.JB, LiteralData{8, 0b01110010}, BG.DATA),
	//
	init_instruction(OpCode.JBE, LiteralData{8, 0b01110110}, BG.DATA),
	init_instruction(OpCode.JP, LiteralData{8, 0b01111010}, BG.DATA),
	init_instruction(OpCode.JO, LiteralData{8, 0b01110000}, BG.DATA),
	init_instruction(OpCode.JS, LiteralData{8, 0b01111000}, BG.DATA),
	init_instruction(OpCode.JNL, LiteralData{8, 0b01111101}, BG.DATA),
	init_instruction(OpCode.JNLE, LiteralData{8, 0b01111111}, BG.DATA),
	init_instruction(OpCode.JNB, LiteralData{8, 0b01110011}, BG.DATA),
	init_instruction(OpCode.JA, LiteralData{8, 0b01110111}, BG.DATA),
	init_instruction(OpCode.JNP, LiteralData{8, 0b01111011}, BG.DATA),
	init_instruction(OpCode.JNO, LiteralData{8, 0b01110001}, BG.DATA),
	init_instruction(OpCode.JNS, LiteralData{8, 0b01111001}, BG.DATA),
	init_instruction(OpCode.LOOP, LiteralData{8, 0b11100010}, BG.DATA),
	init_instruction(OpCode.LOOPZ, LiteralData{8, 0b11100001}, BG.DATA),
	init_instruction(OpCode.LOOPNZ, LiteralData{8, 0b11100000}, BG.DATA),
	init_instruction(OpCode.JCXZ, LiteralData{8, 0b11100011}, BG.DATA),
}

//
// LOGIC
//

get_instruction :: proc(reader: ^BitReader) -> (result: DecodedInstruction, ok: bool) {
	if (finished(reader)) {
		return {}, false
	}

	instr_loop: for instruction in Instructions {
		reset(reader)

		result = DecodedInstruction {
			type = instruction.type,
		}

		direction: Maybe(u8) = {}
		wide: Maybe(u8) = {}
		sign_extended: Maybe(u8) = {}
		mod: Maybe(u8) = {}
		rm: Maybe(u8) = {}
		reg: Maybe(u8) = {}
		data: Maybe(i16) = {}
		disp: Maybe(i16) = {}

		section_loop: for section in instruction.sections {
			bit_group := section.value
			if !section.implied {
				bit_group = read_bits(reader, section.bit_count) or_continue instr_loop
			}

			switch section.group {
			case BG.NONE:
				break section_loop
			case BG.LITERAL:
				if (bit_group != section.value) {
					continue instr_loop
				}
			case BG.D:
				direction = bit_group
			case BG.W:
				wide = bit_group
			case BG.S:
				sign_extended = bit_group
			case BG.MOD:
				mod = bit_group
			case BG.REG:
				reg = bit_group
			case BG.RM:
				rm = bit_group

			// DATA and DISP do not read anything into bit_group since they are defined as 0-sized,
			// so that they can be handled here
			case BG.DATA:
				{
					sign_extended_check := sign_extended == nil || sign_extended.(u8) == 0
					if (wide.(u8) or_else 0) == 1 && sign_extended_check {
						low := cast(u16)read_bits(reader, 8) or_continue instr_loop
						high := cast(u16)read_bits(reader, 8) or_continue instr_loop
						data = transmute(i16)(low | high << 8)
					} else {
						low := read_bits(reader, 8) or_continue instr_loop
						data = cast(i16)transmute(i8)low
					}
				}
			case BG.DISP:
				{
					if mod == 0b01 {
						low := read_bits(reader, 8) or_continue instr_loop
						disp = cast(i16)transmute(i8)low
					} else if (mod == 0b10) || (mod == 0b00 && rm == 0b110) {
						low := cast(u16)read_bits(reader, 8) or_continue instr_loop
						high := cast(u16)read_bits(reader, 8) or_continue instr_loop
						disp = transmute(i16)(low | high << 8)
					}
				}
			}
		}

		// All sections of the instruction matched so we can commit and return
		commit(reader)

		if (wide.(u8) or_else 0) == 1 {
			result.flags += {.Wide}
		}

		if val, ok := reg.(u8); ok {
			result.src = RegisterOperand{val}
		} else if val, ok := data.(i16); ok {
			// immediate to memory has the reg field set to 000
			// and the actual memory address is calculated via mod
			// the direction is implied
			result.src = cast(ImmediateOperand)val
		}

		switch v in mod {
		case u8:
			{
				if mod == 0b11 {
					result.dst = RegisterOperand{rm.(u8)}
				} else if mod == 0b00 && rm.(u8) == 0b110 {
					result.dst = cast(DirectAddrOperand)disp.(i16)
				} else {
					result.dst = EffectiveAddrOperand {
						displacement = disp.(i16) or_else 0,
						disp_width   = cast(DisplacementWidth)v,
						base         = rm.(u8),
					}
				}
			}
		case:
			{
				// Immediate value
				if _, ok := reg.(u8); ok {
					result.dst = result.src
					result.src = cast(ImmediateOperand)data.(i16)
				}
			}
		}

		if (direction.(u8) or_else 0) == 1 {
			temp := result.dst
			result.dst = result.src
			result.src = temp
		}

		return result, true
	}

	return {}, false
}
