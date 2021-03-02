#include <iostream>
#include <iterator>
#include <map>
using namespace std;

map<int, int> m;

int main() {

  for(int i = 0; i < 5; i++)
    m.insert(pair<int, int>(i, 10 * i));

  m.insert(pair<int, int>(1, 2));

  for(auto it = m.begin(); it != m.end(); ++it) {
    cout << '\t' << it->first << '\t' << it->second << endl;
    if(it->second != (10 * it->first))
      return -1;
  }

  m.erase(m.find(2));
  if(m.find(2) != m.end())
    return -1;

  map<int, int>::iterator lb = m.lower_bound(2);
  map<int, int>::iterator ub = m.upper_bound(2);

  if((lb->first != 3) || (ub->first != 3))
    return -1;

  return 0;
}
