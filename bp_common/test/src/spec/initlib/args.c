#if defined(__init_argc) && defined(__init_argv)

int   _argc   = __init_argc;
char* _argv[] = { __init_argv };

#endif
