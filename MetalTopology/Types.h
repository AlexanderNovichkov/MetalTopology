#define index_t uint
#define atomic_index_t atomic_uint

#define MAX_INDEX UINT_MAX

#define OFFSETS_BLOCK_SIZE 8

struct LeftRightPair {
  index_t leftCol;
  index_t rightCol;
};
