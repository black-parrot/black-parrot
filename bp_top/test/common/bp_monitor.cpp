#include "svdpi.h"

#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <cstdio>
#include <cstdint>
#include <string>
#include <cstdlib>
#include <map>
#include <queue>
#include <thread>

using namespace std;

queue<int> getchar_queue;  

void monitor() {
  int c = -1;
  while(1) {
    c = getchar();
    if(c != -1)
      getchar_queue.push(c);
  }
}

extern "C" void start() {
  thread t(&monitor);
  t.detach();
}

extern "C" int scan() {
  if(getchar_queue.empty())
    return -1;
  else
    return getchar_queue.front();
}

extern "C" void pop() {
  if(!getchar_queue.empty())
    getchar_queue.pop();
}
