Description: This tag is from a branch where we experimented with sending
write data along with store misses, so that the combined data was filled into
the cache RAMs directly. The issue with this approach is that while it saves
roughly a single cycle in the cache miss cache, it complicated the data path
added a large mux on the fill path. Instead, reusing the write buffer is a
better approach.
