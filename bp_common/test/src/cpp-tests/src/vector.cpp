#include <iostream> 
#include <vector> 
using namespace std;

vector<int> v;

int main() {

  for(int i = 1; i <= 5; i++)
    v.push_back(i);

  cout << "Output of begin and end: ";
  for(auto i = v.begin(); i != v.end(); ++i) {
    cout << *i << " ";
    if(*i != (i - v.begin() + 1))
      return -1;
  }
  cout << endl;

  cout << "Output of rbegin and rend: ";
  for(auto ir = v.rbegin(); ir != v.rend(); ++ir) {
    cout << *ir << " ";
    if(*ir != (v.rend() - ir))
      return -1;
  }
  cout << endl;

  v.clear();
  v.resize(5);

  for(int i = 0; i < 5; i++)
    v.at(i) = i + 1;

  for(int i = 10; i < 15; i++)
    v.emplace(v.end(), i + 1);

  for(int i = 10; i > 5; i--)
    v.insert(v.begin() + 5, i);

  int N = v.size();
  while(!v.empty()) {
    int val = v.front();
    if(val != (N - v.size() + 1))
      return -1;
    
    cout << val << " ";
    v.erase(v.begin());
  }
  cout << endl;

  return 0;
}
