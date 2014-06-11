.PHONY = all clean
all: 2/dt/dt 2/fsx/fsx-linux 4/seeker/seeker

2/dt/dt:
	cd 2/dt && make

2/fsx/fsx-linux:
	cd 2/fsx && make

4/seeker/seeker:
	cd 4/seeker &&	make

clean:
	cd 2/dt && make clean
	cd 2/fsx && make clean
	cd 4/seeker && make clean
