#include <iostream>
using namespace std;

class parent {
private:
    int id;
public:
    parent(int i) {id = i; cout << "parent constructor " << id <<endl;}
    ~parent() {cout << "parnet destructor " << id <<endl;}
    int getID() {return id;}
};
 
class child : public parent {
public:
    child(int i): parent(i) {cout << "child constructor " << getID() << endl;}
    ~child() {cout << "child destructor " << getID() << endl;}
};

int main()
{
  child c(1);
  {
    parent p(2);
  }

  return 0;
}
