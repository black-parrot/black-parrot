#include <iostream>
using namespace std;

static int counter = 0;

class parent {
private:
    int id;
public:
    parent(int i) {id = i; cout << "parent constructor " << id <<endl;}
    ~parent() {counter++; cout << "parent destructor " << id <<endl;}
    int getID() {return id;}
    void setID(int i) {id = i;}
};
 
class child : public parent {
public:
    child(int i): parent(i) {setID(i+1); cout << "child constructor " << getID() << endl;}
    ~child() {counter++; cout << "child destructor " << getID() << endl;}
};

int main() {

  {
    child c(1);
    if(c.getID() != 2)
      return -1;
    {
      parent p(2);
      if(p.getID() != 2)
        return -1;
    }
   if(counter != 1)
     return -1;
  }
  if(counter != 3)
    return -1;

  return 0;
}
