package emulator

import "core:fmt"
import "core:io"
import "core:os"

BitGroup :: enum {
	NONE,
	LITERAL,
	D, // Direction To/From register
	W, // Word operation
	MOD, // Register Mode, or Memory Mode w/ displacement
	REG, // register operand, or extension of instr
	RM, // register operand, or registers to use in ea
	DATA,
	DISP,
}

BG :: BitGroup

OpCode :: enum {
	MOV,
}

InstructionSection :: struct {
	group:     BG,
	bit_count: u8,
	value:     u8,
}

Instruction :: struct {
	type:     OpCode,
	sections: [10]InstructionSection,
}

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
	OpCode.MOV = "mov",
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

get_instruction :: proc(reader: ^BitReader) -> (result: DecodedInstruction) {
	return result
}

main :: proc() {
	// Check if a file name was provided
	if len(os.args) < 2 {
		fmt.println("Usage: ./8086 <filename>")
		return
	}

	// Get the file name from the command-line argument
	filename := os.args[1]

	// Read the entire file contents
	data, ok := os.read_entire_file_from_filename(filename)
	if !ok {
		fmt.println("Error reading file: ", filename)
		return
	}

	reader := init_bit_reader(data)


}
