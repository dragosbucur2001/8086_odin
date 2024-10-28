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

DecodedInstruction :: struct {
	type: OpCode,
	D:    u8,
	W:    u8,
	MOD:  u8,
	REG:  u8,
	RM:   u8,
	DATA: u16,
	DISP: u16,
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
	// DATA and DISP are 8 or 16 depending on whether MOD and W
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

			switch section.group {
			case BG.NONE:
				break section_loop
			case BG.LITERAL:
				if (bit_group != section.value) {
					continue instr_loop
				}
			case BG.D:
				result.D = bit_group
			case BG.W:
				result.W = bit_group
			case BG.MOD:
				result.MOD = bit_group
			case BG.REG:
				result.REG = bit_group
			case BG.RM:
				result.RM = bit_group

			// DATA and DISP do not read anything into bit_group since they are defined as 0-sized,
			// so that they can be handled here
			case BG.DATA:
				{
					low := cast(u16)read_bits(reader, 8) or_continue instr_loop
					result.DATA = low

					if result.W != 0 {
						high := cast(u16)read_bits(reader, 8) or_continue instr_loop
						result.DATA += high << 8
					}
				}
			case BG.DISP:
				{
					if result.MOD == 0b01 {
						low := cast(u16)read_bits(reader, 8) or_continue instr_loop
						result.DISP = low
					} else if (result.MOD == 0b10) || (result.MOD == 0b00 && result.RM == 110) {
						low := cast(u16)read_bits(reader, 8) or_continue instr_loop
						high := cast(u16)read_bits(reader, 8) or_continue instr_loop
						result.DISP = low | high << 8
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

// for MOD = 11
REG_Encodings := [8][2]string {
	{"al", "ax"},
	{"cl", "cx"},
	{"dl", "dx"},
	{"bl", "bx"},
	{"ah", "sp"},
	{"ch", "bp"},
	{"dh", "si"},
	{"bh", "di"},
}
