instruction_register:
	iverilog -o out \
		Helper.v \
		InstructionRegister.v \
		InstructionRegisterSimulation.v && unbuffer vvp ./out

register_16bit:
	iverilog -o out \
		Helper.v \
		Register16bit.v \
		Register16bitSimulation.v && unbuffer vvp ./out

register_32bit:
	iverilog -o out \
		Helper.v \
		Register32bit.v \
		Register32bitSimulation.v && unbuffer vvp ./out

data_register:
	iverilog -o out \
		Helper.v \
		DataRegister.v \
		DataRegisterSimulation.v && unbuffer vvp ./out

register_file:
	iverilog -o out \
		Helper.v \
		Register32bit.v \
		RegisterFile.v \
		RegisterFileSimulation.v && unbuffer vvp ./out

address_register_file:
	iverilog -o out \
		Helper.v \
		Register16bit.v \
		AddressRegisterFile.v \
		AddressRegisterFileSimulation.v && unbuffer vvp ./out

arithmetic_logic_unit:
	iverilog -o out \
		Helper.v \
		ArithmeticLogicUnit.v \
		ArithmeticLogicUnitSimulation.v && unbuffer vvp ./out

arithmetic_logic_unit_system:
	iverilog -o out \
		Helper.v \
		Register16bit.v \
		Register32bit.v \
		Memory.v \
		AddressRegisterFile.v \
		InstructionRegister.v \
		DataRegister.v \
		RegisterFile.v \
		ArithmeticLogicUnit.v \
		ArithmeticLogicUnitSystem.v \
		ArithmeticLogicUnitSystemSimulation.v && unbuffer vvp ./out

cpu_system:
	iverilog -o out \
	CPUSystemSimulation.v \
	CPUSystem.v \
	ArithmeticLogicUnitSystem.v \
	ArithmeticLogicUnit.v \
	RegisterFile.v \
	AddressRegisterFile.v \
	InstructionRegister.v \
	DataRegister.v \
	Memory.v \
	Register32bit.v \
	Register16bit.v \
	Helper.v && unbuffer vvp ./out

cpu_system_factorial:
	iverilog -o out \
	CPUSystemSimulation_Factorial.v \
	CPUSystem.v \
	ArithmeticLogicUnitSystem.v \
	ArithmeticLogicUnit.v \
	RegisterFile.v \
	AddressRegisterFile.v \
	InstructionRegister.v \
	DataRegister.v \
	Memory.v \
	Register32bit.v \
	Register16bit.v \
	Helper.v && unbuffer vvp ./out

clean:
	rm -f out

all_tests:
	make instruction_register
	make register_16bit
	make register_32bit
	make data_register
	make register_file
	make address_register_file
	make arithmetic_logic_unit
	make arithmetic_logic_unit_system