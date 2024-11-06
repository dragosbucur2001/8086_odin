package emulator

import "core:log"
import "core:os"
import "core:testing"

is_wide :: proc(instr: ^DecodedInstruction) -> u8 {
	return (InstrFlags.Wide in instr.flags) ? 1 : 0
}

ExpImmediate :: distinct i16
ExpReg :: distinct string
ExpDirAddr :: distinct i16
ExpEffective :: struct {
	base:       string,
	disp:       i16,
	disp_width: DisplacementWidth,
}
ExpectedGrouping :: union #no_nil {
	ExpImmediate,
	ExpReg,
	ExpDirAddr,
	ExpEffective,
}

ExpectedInstr :: struct {
	type:     OpCode,
	grouping: [2]ExpectedGrouping,
}

check_operand :: proc(test: ^t.T, expected: ExpectedGrouping, operand: Operand, W: u8) {
	switch exp in expected {
	case ExpImmediate:
		{
			op, _ := operand.(ImmediateOperand)
			t.expect(test, cast(i16)op == cast(i16)exp)
		}
	case ExpReg:
		{
			op, _ := operand.(RegisterOperand)
			t.expect(test, RegisterName[op.reg][W] == cast(string)exp)
		}
	case ExpEffective:
		{
			op, _ := operand.(EffectiveAddrOperand)
			t.expect(test, EffectiveOperandBase[op.base] == exp.base)
			t.expect(test, op.disp_width == exp.disp_width)
			t.expect(test, op.displacement == exp.disp)
		}
	case ExpDirAddr:
		{
			op, _ := operand.(DirectAddrOperand)
			t.expect(test, cast(i16)op == cast(i16)exp)
		}
	}
}


@(test)
decode_mov :: proc(test: ^t.T) {
	data, ok_file := os.read_entire_file_from_filename("./tests/listing_0037_single_register_mov")
	defer delete(data)

	if !ok_file {
		t.fail_now(test)
	}

	reader := init_bit_reader(data)

	// mov cx, bx
	instr, ok := get_instruction(&reader)
	t.expect(test, ok)
	t.expect(test, instr.type == OpCode.MOV)

	t.expect(test, InstrFlags.Wide in instr.flags)
	W := (InstrFlags.Wide in instr.flags) ? 1 : 0

	dst, _ := instr.dst.(RegisterOperand)
	t.expect(test, RegisterName[dst.reg][W] == "cx")

	src, _ := instr.src.(RegisterOperand)
	t.expect(test, RegisterName[src.reg][W] == "bx")
}

@(test)
decode_mov_many_register :: proc(test: ^t.T) {
	data, ok_file := os.read_entire_file_from_filename("./tests/listing_0038_many_register_mov")
	defer delete(data)

	if !ok_file {
		t.fail_now(test)
	}

	reader := init_bit_reader(data)

	expected := [?][2]ExpectedGrouping {
		{"cx", "bx"},
		{"ch", "ah"},
		{"dx", "bx"},
		{"si", "bx"},
		{"bx", "di"},
		{"al", "cl"},
		{"ch", "ch"},
		{"bx", "ax"},
		{"bx", "si"},
		{"sp", "di"},
		{"bp", "ax"},
	}

	for grouping in expected {
		instr, ok := get_instruction(&reader)
		t.expect(test, instr.type == OpCode.MOV)
		t.expect(test, ok)

		W := is_wide(&instr)

		check_operand(test, grouping[0], instr.dst, W)
		check_operand(test, grouping[1], instr.src, W)
	}
}

@(test)
decode_mov_complex :: proc(test: ^t.T) {
	data, ok_file := os.read_entire_file_from_filename("./tests/listing_0039_more_movs")
	defer delete(data)

	if !ok_file {
		t.fail_now(test)
	}

	reader := init_bit_reader(data)

	// dst, src
	expected := [?][2]ExpectedGrouping {
		{"si", "bx"},
		{"dh", "al"},
		{"cl", cast(ExpImmediate)12},
		{"ch", cast(ExpImmediate)-12},
		{"cx", cast(ExpImmediate)12},
		{"cx", cast(ExpImmediate)-12},
		{"dx", cast(ExpImmediate)3948},
		{"dx", cast(ExpImmediate)-3948},
		{"al", ExpEffective{"bx + si", 0, .BIT_0}},
		{"bx", ExpEffective{"bp + di", 0, .BIT_0}},
		{"dx", ExpEffective{"bp", 0, .BIT_8}}, // bp with a disp width of 0 is actually a dirrect address
		{"ah", ExpEffective{"bx + si", 4, .BIT_8}},
		{"al", ExpEffective{"bx + si", 4999, .BIT_16}},
		{ExpEffective{"bx + di", 0, .BIT_0}, "cx"},
		{ExpEffective{"bp + si", 0, .BIT_0}, "cl"},
		{ExpEffective{"bp", 0, .BIT_8}, "ch"},
	}

	for grouping in expected {
		instr, ok := get_instruction(&reader)
		t.expect(test, instr.type == OpCode.MOV)
		t.expect(test, ok)

		W := is_wide(&instr)

		check_operand(test, grouping[0], instr.dst, W)
		check_operand(test, grouping[1], instr.src, W)
	}
}

@(test)
decode_mov_challenge :: proc(test: ^t.T) {
	data, ok_file := os.read_entire_file_from_filename("./tests/listing_0040_challenge_movs")
	defer delete(data)

	if !ok_file {
		t.fail_now(test)
	}

	reader := init_bit_reader(data)

	// dst, src
	expected := [?][2]ExpectedGrouping {
		{"ax", ExpEffective{"bx + di", -37, .BIT_8}},
		{ExpEffective{"si", -300, .BIT_16}, "cx"},
		{"dx", ExpEffective{"bx", -32, .BIT_8}},
		{ExpEffective{"bp + di", 0, .BIT_0}, cast(ExpImmediate)7},
		{ExpEffective{"di", 901, .BIT_16}, cast(ExpImmediate)347},
		{"bp", cast(ExpDirAddr)5},
		{"bx", cast(ExpDirAddr)3458},
		{"ax", cast(ExpDirAddr)2555},
		{"ax", cast(ExpDirAddr)16},
		{cast(ExpDirAddr)2554, "ax"},
		{cast(ExpDirAddr)15, "ax"},
	}

	for grouping in expected {
		instr, ok := get_instruction(&reader)
		t.expect(test, instr.type == OpCode.MOV)
		t.expect(test, ok)

		W := is_wide(&instr)

		check_operand(test, grouping[0], instr.dst, W)
		check_operand(test, grouping[1], instr.src, W)
	}
}

@(test)
decode_add_sub_cmp_jnz :: proc(test: ^t.T) {
	data, ok_file := os.read_entire_file_from_filename("./tests/listing_0041_add_sub_cmp_jnz")
	defer delete(data)

	if !ok_file {
		t.fail_now(test)
	}

	reader := init_bit_reader(data)

	add_weird_grouping := [2]ExpectedGrouping {
		ExpEffective{"bp + si", 1000, .BIT_16},
		cast(ExpImmediate)29,
	}

	// dst, src
	expected_instrunctions := [?]OpCode{.ADD, .SUB, .CMP}
	expected_grouping := [?][2]ExpectedGrouping {
		{"bx", ExpEffective{"bx + si", 0, .BIT_0}},
		{"bx", ExpEffective{"bp", 0, .BIT_8}},
		{"si", cast(ExpImmediate)2},
		{"bp", cast(ExpImmediate)2},
		{"cx", cast(ExpImmediate)8},
		{"bx", ExpEffective{"bp", 0, .BIT_8}},
		{"cx", ExpEffective{"bx", 2, .BIT_8}},
		{"bh", ExpEffective{"bp + si", 4, .BIT_8}},
		{"di", ExpEffective{"bp + di", 6, .BIT_8}},
		{ExpEffective{"bx + si", 0, .BIT_0}, "bx"},
		{ExpEffective{"bp", 0, .BIT_8}, "bx"},
		{ExpEffective{"bp", 0, .BIT_8}, "bx"},
		{ExpEffective{"bx", 2, .BIT_8}, "cx"},
		{ExpEffective{"bp + si", 4, .BIT_8}, "bh"},
		{ExpEffective{"bp + di", 6, .BIT_8}, "di"},
		{ExpEffective{"bx", 0, .BIT_0}, cast(ExpImmediate)34},
		add_weird_grouping,
		{"ax", ExpEffective{"bp", 0, .BIT_8}},
		{"al", ExpEffective{"bx + si", 0, .BIT_0}},
		{"ax", "bx"},
		{"al", "ah"},
		{"ax", cast(ExpImmediate)1000},
		{"al", cast(ExpImmediate)-30},
		{"al", cast(ExpImmediate)9},
	}

	for instr_type in expected_instrunctions {
		for grouping_ in expected_grouping {
			grouping: [2]ExpectedGrouping = grouping_

			// This operation is sligthly different for sub
			if (instr_type == OpCode.SUB && grouping == add_weird_grouping) {
				grouping = {ExpEffective{"bx + di", 0, .BIT_0}, cast(ExpImmediate)29}
			}

			if (instr_type == OpCode.CMP && grouping == add_weird_grouping) {
				grouping = {cast(ExpDirAddr)4834, cast(ExpImmediate)29}
			}

			//log.info(grouping)
			instr, ok := get_instruction(&reader)
			t.expect(test, instr.type == instr_type)
			t.expect(test, ok)
			//log.info(instr)

			W := is_wide(&instr)

			check_operand(test, grouping[0], instr.dst, W)
			check_operand(test, grouping[1], instr.src, W)
		}
	}


}
