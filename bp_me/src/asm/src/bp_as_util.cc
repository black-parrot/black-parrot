/*
 * bp_as_util.cc
 *
 * BlackParrot CCE Microcode Assembler
 *
 * Input tokenize and general utility functions
 *
 */

#include "bp_as.h"

/*
 * Constructor and Destructor
 */

Assembler::Assembler() {
  infp = stdin;
  outfp = stdout;
  line_number = 0;
  debug_mode = false;

  printf("instruction length: %d\n", bp_cce_inst_s_width);
}

Assembler::~Assembler() {
  if (infp != stdin) {
    fclose(infp);
  }
  if (outfp != stdout) {
    fclose(outfp);
  }
}

/*
 * Argument Parsing
 */

void
Assembler::parseArgs(int argc, char *argv[]) {
  int i = 1;

  while (i < argc) {
    if (argv[i][0] == '-') {
      switch(argv[i][1]) {
        case  'i':
        case  'I':
          infp = fopen(argv[i + 1], "r");
          if (!infp) {
            printf("Failure to open input file: %s\n", argv[i + 1]);
            exit(__LINE__);
          }
          i += 2;
          break;
        case  'o':
        case  'O':
          outfp = fopen(argv[i + 1], "w");
          if (!outfp) {
            printf("Failure to create output file: %s\n", argv[i + 1]);
            exit(__LINE__);
          }
          i += 2;
          break;
        case  'b':
        case  'B':
          output_format = output_format_ascii_binary;
          ++i;
          break;
        case  'd':
        case  'D':
          output_format = output_format_dbg;
          debug_mode = true;
          ++i;
          break;
        default:
          printf("Usage:\n"
            "\t-i <input>   input file\n"
            "\t-o <output>    output file\n"
            "\t-b       output ascii binary\n"
            "\t-d       output debug\n");
          exit(__LINE__);
      }
    } else {
      printf("Try -- for help\n");
      exit(-__LINE__);
    }
  }
}

/*
 * Utility Functions
 */

bool
Assembler::_iscommentstart(char ch) {
  switch (ch) {
    case  '#':
      return true;
    default:
      return false;
  }
}

bool
Assembler::_iswhitespace(char ch) {
  switch (ch) {
    case  '/':
    case  ',':
    case  ' ':
    case  '\t':
      return true;
    default:
      return false;
  }
}

bool
Assembler::_ishardnewline(char ch) {
  switch (ch) {
    case  '\0':
    case  '\n':
      return true;
    default:
      return false;
  }
}

bool
Assembler::_isnewline(char ch) {
  switch (ch) {
    case  '\0':
    case  '\n':
    case  ';':
      return true;
    default:
      return false;
  }
}

char
Assembler::_lowercase(char ch) {
  if (ch >= 'A' && ch <= 'Z')
    return ch - 'A' + 'a';
  return ch;
}

/*
 * Tokenize Functions
 */

int
Assembler::readLine(char *s, int maxLineLen, FILE *infp) {
  char ch;
  int n = 0;

  while (n < maxLineLen) {
    // end of file
    if (feof(infp)) {
      if (n > 0)
        return n;
      else
        return -1;
    }

    // read next character
    ch = fgetc(infp);

    // eof character check
    if (feof(infp) && n == 0) {
      return -1;
    }

    // comment character at start of line, discard line
    if (_iscommentstart(ch) && n == 0) {
      // read through newline or EOF
      fgets(s, maxLineLen, infp);
      continue;
    }

    // Skip white space at the start of a line
    if ((_iswhitespace(ch) || _isnewline(ch)) && n == 0) {
      continue;
    }

    // Update the line number if needed
    if (_ishardnewline(ch)) {
      ++line_number;
    }

    // end of line, return
    if (_isnewline(ch) && n != 0) {
      *s = '\0';
      return n;
    }

    // comment in middle of line, consume rest of line and return
    if (_iscommentstart(ch) && n != 0) {
      *s = '\0';
      // consume rest of line, up to new line
      ch = fgetc(infp);
      while (ch) {
        if (_isnewline(ch)) {
          // newline character found, erase whitespace at end of line
          --s;
          --n;
          while (_iswhitespace(*s)) {
            --s;
            --n;
          }
          ++s;
          *s = '\0';
          return n;
        }
        ch = fgetc(infp);
      }
      printf("returning after while loop\n");
      return n;
    }

    *s = _lowercase(ch);
    ++s;
    ++n;
  }
  printf("Long line on input\n");
  exit(-__LINE__);
}

int
Assembler::tokenizeLine(char* input_line, char tokens[MAX_TOKENS][MAX_LINE_LENGTH]) {
  // Parse the input line into individual tokens
  // current token
  int token = 0;
  // character position within current token
  int i = 0;
  // character iterator for line
  char *s = input_line;

  // initialize tokens to null strings
  for (token = 0; token < MAX_TOKENS; token++) {
    tokens[token][0] = '\0';
  }

  token = 0;
  while (*s) {
    if (token >= MAX_TOKENS) {
      if (!(*s)) {
        printf("Cannot parse: (%d) %s\n", line_number-1, input_line);
        exit(-__LINE__);
      }
      break;
    }

    // whitespace character, terminate this token
    if (_iswhitespace(*s)) {
      tokens[token][i] = '\0';
      i = 0;
      ++token;
      ++s;
      // consume whitespace
      while (*s && _iswhitespace(*s)) {
        ++s;
      }
    // normal character, add to token
    } else {
      tokens[token][i] = *s;
      ++i;
      ++s;
    }
  }

  // after reading last valid character of the line, terminate the last token
  if (!(*s) && i > 0) {
    tokens[token][i] = '\0';
    ++token;
  }

  return token;
}

int
Assembler::parseLabels(char tokens[MAX_TOKENS][MAX_LINE_LENGTH], int n, uint16_t addr) {
  // parse label if present
  string s (tokens[0]);
  if (s.back() == ':') {
    if (labels_to_addr.find(s) == labels_to_addr.end()) {
      s = s.substr(0, s.size()-1);
      labels_to_addr.insert(pair<string, uint16_t>(s, addr));
      // remove the label from the tokens
      for (int i = 1; i < n; i++) {
        memcpy(tokens[i-1], tokens[i], strlen(tokens[i])+1);
      }
      tokens[n-1][0] = '\0';
      return n-1;
    } else {
      printf("Duplicate label: %s\n", tokens[0]);
      exit(-1);
    }
  }
  return n;
}

void
Assembler::tokenizeAndLabel() {
  // Read all lines, tokenize, and remove labels (while assigning to addresses)
  while (readLine(input_line, MAX_LINE_LENGTH, infp) > 0) {
    uint16_t addr = line_number-1;

    printf("(%d) %s\n", addr, input_line);

    lines.push_back(string(input_line));

    int numTokens = tokenizeLine(input_line, input_line_tokens);

    numTokens = parseLabels(input_line_tokens, numTokens, addr);

    vector<string> *inst_tokens = new vector<string>();
    for (int i = 0; i < numTokens; i++) {
      inst_tokens->push_back(string(input_line_tokens[i]));
    }
    tokens.push_back(inst_tokens);
    num_tokens.push_back(numTokens);
  }
}

/*
 * Output Utility / Print Functions
 */

void
Assembler::printField(uint32_t b, int bits, stringstream &ss) {
  int i = 0;
  uint32_t mask = (1 << (bits-1));
  while (i < bits) {
    if (b & mask) {
      ss << "1";
    } else {
      ss << "0";
    }
    mask = mask >> 1;
    ++i;
  }
}

void
Assembler::printPad(int bits, stringstream &ss) {
  for (int i = 0; i < bits; i++) {
    ss << "0";
  }
}

