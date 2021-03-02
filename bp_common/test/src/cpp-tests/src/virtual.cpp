#include <iostream>
using namespace std;

class parent {
public:
    void fun_1() { cout << "parent-1\n"; }
    virtual void fun_2() { cout << "parent-2\n"; }
    virtual void fun_3() { cout << "parent-3\n"; }
    virtual void fun_4() { cout << "parent-4\n"; }
};
 
class child : public parent {
public:
    void fun_1() { cout << "child-1\n"; }
    void fun_2() { cout << "child-2\n"; }
    void fun_4(int x) { cout << "child-4\n"; }
};

int main()
{
	parent* p;
	child c;
	p = &c;

	// Early binding to parent class
	p->fun_1();

	// Late binding
	p->fun_2();

	// Late binding
	p->fun_3();

	// Late binding
	p->fun_4();

	// Early binding to child class
	c.fun_4(1);

	return 0;
}
