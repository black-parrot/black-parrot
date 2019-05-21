/*
 * THIS DEMO IS NO LONGER SUPPORTED AND IS HERE ONLY FOR REFERENCE
 */

#include <stdint.h>

#define QUEUE_LENGTH 32

#ifndef NUM_CORES
#define NUM_CORES 4
#endif

#define NUM_READERS (NUM_CORES/2)
#define NUM_WRITERS (NUM_CORES/2)

#define NUM_OPS 10


// this is just a circular queue
// we dequeue at the head index and enqueue from the tail index
typedef struct {
    uint64_t head_index;
    uint64_t tail_index;
    uint64_t queue_buffer[QUEUE_LENGTH];
} shared_queue;

typedef struct {
    uint64_t barrier_mem;
    shared_queue queue;
    uint64_t queue_entering[NUM_WRITERS + NUM_READERS];
    uint64_t queue_num[NUM_WRITERS + NUM_READERS];
} shared_state;
// FIXME: we can change this into a struct if we
// want a more complex queue
typedef uint64_t queue_item;

// declare everything volatile, so loops don't optimize themselves away

void lock_queue(volatile shared_state *state, uint64_t core_id) {
    uint64_t i, j;
    uint64_t max = 0;
    (state->queue_entering)[core_id] = 1;
//    __asm__ volatile("fence": : :);
    for(i = 0; i < (NUM_READERS + NUM_WRITERS); i++) {
        if ((state->queue_num)[i] > max) {
            max = (state->queue_num)[i];
        }
    }
    (state->queue_num)[core_id] = 1 + max;
    (state->queue_entering)[core_id] = 0;
//    __asm__ volatile("fence": : :);

    for (j = 0; j < (NUM_READERS + NUM_WRITERS); j++) {
        while ((state->queue_entering)[j]) { /* just spin */}

        while ((state->queue_num)[j] != 0 &&
              ((state->queue_num)[core_id] > (state->queue_num)[j] ||
              ((state->queue_num)[core_id] == (state->queue_num)[j] && core_id > j))) {

        }
    }
}

void unlock_queue(volatile shared_state *state, uint64_t core_id) {
    (state->queue_num)[core_id] = 0;
//    __asm__ volatile("fence": : :);
}

// attempts to enqueue an item.
// returns 0 if successful
// returns 1 if unsuccessful (the queue was full)
uint64_t enqueue(volatile shared_state *state,
                 uint64_t core_id, queue_item enqueue_item) {
    uint64_t status = 0;
    // we actually don't care if the head index changes between
    // us checking and us enqueuing because we don't need to
    // change things based on head index
    // We might miss a consumer dequeue, so we don't enqueue
    // immediately to fill an empty slot, but so what
    lock_queue(state, core_id);

    // if the queue is full, return an error
    // the queue is full
    if (((state->queue).tail_index + 1) % QUEUE_LENGTH == (state->queue).head_index) {
        status = 1;
        goto done_enqueue;
    }

    // FIXME: if a queue_item becomes a struct, change to copying
    // in the struct fields
    (state->queue).queue_buffer[(state->queue).tail_index] = enqueue_item;

    // update the tail index at the very end, so if a consumer
    // checks to dequeue, the item will be ready
    (state->queue).tail_index = ((state->queue).tail_index + 1) % QUEUE_LENGTH;
    //printf("Core %d enqueued %d\n", core_id, enqueue_item);

done_enqueue:
    unlock_queue(state, core_id);
    return status;
}

// attempts to dequeue an item.
// returns 0 if successful
// returns 1 if unsuccessful (the queue was full)
// the item is returned in dequeue_item
uint64_t dequeue(volatile shared_state *state,
                 uint64_t core_id, queue_item *dequeue_item) {
    uint64_t status = 0;
    uint64_t print_addr = (uint64_t)(0x000000008FFFFFFF);
    uint64_t print_item;

    // we actually don't care if the tail index changes between
    // us checking and us dequeuing because we don't need to
    // change things based on tail index
    // We might miss a producer enqueue, so we don't dequeue
    // a new item immediately, but so what
    lock_queue(state, core_id);

    // check if the queue is empty
    if ((state->queue).tail_index == (state->queue).head_index) {
        status = 1;
        goto done_dequeue;
    }

    // FIXME: if a queue_item becomes a struct, change to copying in the struct fields
    *dequeue_item = (state->queue).queue_buffer[(state->queue).head_index];

    // update the head index at the very end, so if a producer checks to
    // enqueue, the item will have already been copied out
    (state->queue).head_index = ((state->queue).head_index + 1) % QUEUE_LENGTH;
    print_item = *dequeue_item;
    //printf("Core %d dequeued %d\n", core_id, *dequeue_item);
    __asm__ volatile("sb %0, 0(%1)": : "r"(print_item), "r"(print_addr):);

done_dequeue:
    unlock_queue(state, core_id);
    return status;
}

// TODO: what actually happens when we enqueue and dequeue
// this will eventually become the function given to pthread_create
uint64_t thread_main(volatile shared_state *state) {
    // do some stuff, probably dependent on core ID (enqueue vs dequeue)
    // find some inline assembly to read the hartID csr
    uint64_t data = 0;
    uint64_t core_id;
    uint64_t status;
    uint64_t num_operations = 0;
    
    __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);
    // have the even cores enqueue and the odd ones dequeue
    if (core_id % 2 == 0){
        while(num_operations < NUM_OPS) {
            status = enqueue(state, core_id, data);
            if (status == 0) {
                data++;
                num_operations++;
                //TODO: do something on enqueue
            }
        }
    }
    else {
        while(num_operations < NUM_OPS) {
            status = dequeue(state, core_id, &data);
            if (status == 0) {
                // TODO: do something with dequeued data...maybe print?
                num_operations++;
            }
        }
    }
    return 0;
}

uint64_t main(uint64_t argc, char * argv[]) {
    uint64_t i;
    uint64_t core_id;
    volatile shared_state *state = (volatile shared_state *)0x000000008FFFDFF0;
    /*
    volatile uint64_t *barrier_mem = 0x000000008FFFDFF0;
    volatile shared_queue *queue = ((uint64_t)barrier_mem) + sizeof(uint64_t);
    volatile uint64_t *queue_entering = ((uint64_t)queue) + sizeof(shared_queue);
    volatile uint64_t *queue_num = ((uint64_t)queue_entering) + 
        (sizeof(uint64_t) * (NUM_READERS+NUM_WRITERS));
*/
    __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);
   
    // only core 0 intializes data structures
    if (core_id == 0) {
        // initialize queue lock
        for (i = 0; i < (NUM_READERS + NUM_WRITERS); i++) {
            (state->queue_entering)[i] = 0;
            (state->queue_num)[i] = 0;
        }
        // initialize queue structure
        (state->queue).head_index = 0;
        (state->queue).tail_index = 0;
        for (i = 0; i < QUEUE_LENGTH; i++) {
            (state->queue).queue_buffer[i] = 0xdeadbeef;
        }
        state->barrier_mem = 0xdeadbeef;
        thread_main(state);
    }
    // every other thread should copy their code into their own little section
    else {
        uint64_t offset = core_id << 12;
        uint64_t *copy_start = (uint64_t *)(0x00000000800001c4);
        uint64_t *copy_end = (uint64_t *)(0x00000000800005fc);
        uint64_t *copy_addr;
        uint64_t *copy_dest = (uint64_t *)(0x00000000800001c4 + offset);
        uint64_t (*copied_thread_main)(volatile shared_state *) = 
            (uint64_t *)(0x0000000080000530 + offset);

        for (copy_addr = copy_start; copy_addr <= copy_end; 
                copy_addr += 1, copy_dest += 1) {
            *copy_dest = *copy_addr;
        }

        while (state->barrier_mem != 0xdeadbeef) { }
        copied_thread_main(state);
    }
    return 0;
}
