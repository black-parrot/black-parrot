#include <iostream>
using namespace std;

void exceptionFun(int x) {
  try {
    cout << "Inside try" << endl;
    if (x < 0) {
      throw x;
      cout << "After throw (Never executed)" << endl;
    }
  }
  catch (int x) {
    cout << "Exception caught for " << x << endl;
  }
}

int main()
{
  exceptionFun(1);
  exceptionFun(-1);

  return 0;
}
