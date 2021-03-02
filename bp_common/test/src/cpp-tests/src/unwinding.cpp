#include <iostream>
using namespace std;

void f1(int x) {
  throw x;
  cout << "After throw (Never executed)" << endl;
  exit(-1);
}

void f2(int x) {
  try {
    f1(x);
  }
  catch (int x) {
    cout << "f2: Exception caught for " << x << endl;
  }
}

void f3(int x) {
  try {
    throw x;
    cout << "After throw (Never executed)" << endl;
    exit(-1);
  }
  catch (int x) {
    cout << "f3: Exception caught for " << x << endl;
  }
}

int main()
{
  f3(3);
  f2(2);
  try {
    f1(1);
  }
  catch (int x) {
    cout << "main: Exception caught for " << x << endl;
  }

  return 0;
}
