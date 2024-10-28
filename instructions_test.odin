package emulator

import "core:os"
import "core:testing"

@(test)
read_mov :: proc(test: ^t.T) {
	data, ok_file := os.read_entire_file_from_filename("./tests/listing_0037_single_register_mov")
	defer delete(data)

	if !ok_file {
		t.fail_now(test)
	}

	reader := init_bit_reader(data)

	instr, ok := get_instruction(&reader)
	t.expect(test, ok)
	t.expect(test, instr.type == OpCode.MOV)
	t.expect(test, instr.D == 0b0)
	t.expect(test, instr.W == 0b1)
	t.expect(test, instr.MOD == 0b11)
	t.expect(test, instr.REG == 0b011)
	t.expect(test, instr.RM == 0b001)

	instr, ok = get_instruction(&reader)
	t.expect(test, !ok)
	t.expect(test, instr.type == OpCode.NONE)
}
