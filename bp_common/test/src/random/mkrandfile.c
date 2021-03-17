#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define DEFAULT_DATA_CNT 512


// Put your custom RNG algorithm here
void rand_init(unsigned seed)
{
	srand(seed);
}
unsigned char get_rand()
{
	return rand() & 255U;
}


int string_to_int(const char *str, unsigned *num)
{
	int i = 0;
	int ch;
	*num = 0;
	while((ch = str[i]) != '\0') {
		if(ch < '0' || ch > '9')
			break;
		*num *= 10;
		*num += (str[i++] - '0');
	}
	if(str[i] == '\0')
		return 0;
	else
		return 1;
}


unsigned get_default_seed()
{
	unsigned seed;
	FILE *fp = fopen("/dev/urandom", "r");
	if(fp)
		fread(&seed, sizeof(seed), 1, fp);
	else 
		seed = 54321;

	return seed;
}


void write_rand_data(FILE *output, unsigned seed, unsigned size)
{
	printf("[mkrandfile] Generating random numbers ...\nseed: %u, size: %u\n", \
			seed, size);

	rand_init(seed);
	for(unsigned i = 0;i < size;i++) {
		unsigned char data;
		data = get_rand();
		printf("%u\n", data);
		fwrite(&data, sizeof(data), 1, output);
	}
}

int main(int argc, char **argv)
{
	FILE *output = NULL;
	unsigned seed = 0;
	unsigned size = DEFAULT_DATA_CNT;

	// argc cannnot be even
	if(!(argc % 2))
		goto error;
	
	for(int i = 1;i < argc;i += 2) {
		const char *str = argv[i];
		const char *arg = argv[i + 1];
		if(!strcmp(str, "-seed")) {
			if(string_to_int(arg, &seed))
				goto error;
		}
		else if(!strcmp(str, "-size")) {
			if(string_to_int(arg, &size))
				goto error;
		}
		else if(!strcmp(str, "-o")) {
			output = fopen(arg, "w");
			if(output == NULL)
				goto error;
		}
		else {
			goto error;
		}
	}
	
	if(seed == 0) {
		seed = get_default_seed();
	}
	if(output == NULL) {
		output = fopen("rand_out", "w");
		if(output == NULL)
			goto error;
	}

	write_rand_data(output, seed, size);


	fclose(output);

	return 0;
error:
	fprintf(stderr, "Usage: mkrandfile [-size RAND_SIZE] [-seed RAND_SEED] [-o output_file]\n");
	return 1;
}



