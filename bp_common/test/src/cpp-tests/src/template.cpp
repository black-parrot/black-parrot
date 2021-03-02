#include <iostream>
using namespace std;

template <typename T> 
T myMax(T x, T y) 
{ 
   return (x > y)? x : y; 
}

class A {
private:
    int id;
public:
    A(int i) {id = i;}
    bool operator>(const A &a) {return id > a.id;}
    friend ostream& operator<<(ostream& os, const A& a);
};

ostream& operator<<(ostream& os, const A& a) {
  os << "A(id=" << a.id << ")";
  return os;
}

int main()
{
  cout << myMax<int>(3, 7) << endl;
  cout << myMax<double>(3.0, 7.0) << endl;
  cout << myMax<char>('g', 'e') << endl;
  cout << myMax<A>(A(3), A(7)) << endl;
  return 0;
}
