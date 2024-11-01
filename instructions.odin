package emulator

//
// DEFINITIONS
//

BitGroup :: enum {
	NONE,
	LITERAL,
	D, // Direction To/From register
	W, // wide or not
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
}

OpCode :: enum {
	NONE,
	MOV,
}

Instruction :: struct {
	type:     OpCode,
	sections: [10]InstructionSection,
}

ImmediateOperand :: distinct i32

DirectAddrOperand :: distinct i32

OpWidth :: enum {
	BIT_0,
	BIT_8,
	BIT_16,
}

EffectiveAddrOperand :: bit_field u8 {
	width: OpWidth | 2, // mod field
	base:  u8      | 3, // rm field
}

EffectiveOperandBase :: [8]string {
	"bx + si",
	"bx + di",
	"bp + si",
	"bp + di",
	"si",
	"di",
	"bx",
	"bp",
}

RegisterOperand :: bit_field u8 {
	reg:   u8 | 3,
	width: u8 | 1, // w field
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

DecodedInstruction :: struct {
	type:     OpCode,
	operands: [2]Operand,
}

//
// INITIALISATION & GLOBALS
//

BitGroupSizes := [BitGroup]u8 {
	BG.NONE    = 0,
	BG.LITERAL = 0,
	BG.D       = 1,
	BG.W       = 1,
	BG.MOD     = 2,
	BG.REG     = 3,
	BG.RM      = 3,
	// DATA and DISP are 8 or 16 depending on MOD and W
	BG.DATA    = 0,
	BG.DISP    = 0,
}


OpCodeNames := [OpCode]string {
	OpCode.NONE = "ERROR",
	OpCode.MOV  = "mov",
}

@(private)
LiteralData :: struct {
	bit_count: u8,
	value:     u8,
}

init_instruction :: proc(type: OpCode, sections: ..union #no_nil {
		LiteralData,
		BG,
	}) -> (result: Instruction) {
	result.type = type

	for section, idx in sections {
		switch unwrapped in section {
		case LiteralData:
			{
				assert(unwrapped.bit_count > 0 && unwrapped.bit_count <= 8)

				result.sections[idx] = InstructionSection {
					group     = BG.LITERAL,
					bit_count = unwrapped.bit_count,
					value     = unwrapped.value,
				}
			}
		case BG:
			{
				result.sections[idx] = InstructionSection {
					group     = unwrapped,
					bit_count = BitGroupSizes[unwrapped],
					value     = 0,
				}
			}
		}
	}

	return result
}

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
	// immidiate to register
	init_instruction(OpCode.MOV, LiteralData{4, 0b1011}, BG.W, BG.REG, BG.DATA),
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

		section_loop: for section in instruction.sections {
			bit_group := read_bits(reader, section.bit_count) or_continue instr_loop

			direction: Maybe(u8) = {}
			wide: Maybe(u8) = {}
			mod: Maybe(u8) = {}
			rm: Maybe(u8) = {}
			reg: Maybe(u8) = {}
			data: Maybe(u16) = {}
			disp: Maybe(u16) = {}

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
					low := cast(u16)read_bits(reader, 8) or_continue instr_loop
					data = low

					if wide != 0 && wide != nil {
						high := cast(u16)read_bits(reader, 8) or_continue instr_loop
						data = low | high << 8
					}
				}
			case BG.DISP:
				{
					if mod == 0b01 {
						low := cast(u16)read_bits(reader, 8) or_continue instr_loop
						disp = low
					} else if (mod == 0b10) || (mod == 0b00 && rm == 110) {
						low := cast(u16)read_bits(reader, 8) or_continue instr_loop
						high := cast(u16)read_bits(reader, 8) or_continue instr_loop
						disp = low | high << 8
					}
				}
			}
		}

		// All sections of the instruction matched so we can commit and return
		commit(reader)


		return result, true
	}

	return {}, false
}
