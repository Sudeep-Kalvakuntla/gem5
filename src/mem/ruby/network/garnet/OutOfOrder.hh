#include "mem/ruby/network/garnet/flit.hh"
//#include <bitset>

namespace gem5 {
namespace ruby {
namespace garnet {
    class flit; 
}
}
}


namespace OOO{
//Namespace for out of order

#define GET_MASK(w)           ((w >= 64) ? ~0ULL : (1ULL << w) - 1) //Creates a mask of 1s based on the field's width

#define FLIT_SIZE              72

//                                  Head flit format (72 bits)
//   71               55      47      43       39       31       23       15        7        0
// +----------------+--------+-------+--------+--------+--------+--------+--------+--------+
// |      rsvd      |seq_num | vc_id |  type  | src_ni | src_rt | dst_ni | dst_rt |  hops  |
// +----------------+--------+-------+--------+--------+--------+--------+--------+--------+
// |       16       |   8    |   4   |   4    |   8    |   8    |   8    |   8    |   8    |
// +----------------+--------+-------+--------+--------+--------+--------+--------+--------+
// |       56       |   48   |  44   |  40    |   32   |   24   |   16   |   8    |   0    |

// --- Head Flit Widths ---
#define W_PAYLOAD_HEAD         0 
#define W_HOPS_TRAVERSED_HEAD  8
#define W_DEST_ROUTER_HEAD     8
#define W_DEST_NI_HEAD         8
#define W_SRC_ROUTER_HEAD      8
#define W_SRC_NI_HEAD          8
#define W_TYPE_HEAD            4
#define W_VC_ID_HEAD           4
#define W_SEQ_NUM_HEAD         8
#define W_RESERVED_HEAD        16

// --- Head Flit Cumulative Offsets ---
#define O_PAYLOAD_HEAD         0
#define O_HOPS_TRAVERSED_HEAD  0
#define O_DEST_ROUTER_HEAD     (O_HOPS_TRAVERSED_HEAD + W_HOPS_TRAVERSED_HEAD)
#define O_DEST_NI_HEAD         (O_DEST_ROUTER_HEAD + W_DEST_ROUTER_HEAD)
#define O_SRC_ROUTER_HEAD      (O_DEST_NI_HEAD + W_DEST_NI_HEAD)
#define O_SRC_NI_HEAD          (O_SRC_ROUTER_HEAD + W_SRC_ROUTER_HEAD)
#define O_TYPE_HEAD            (O_SRC_NI_HEAD + W_SRC_NI_HEAD)
#define O_VC_ID_HEAD           (O_TYPE_HEAD + W_TYPE_HEAD)
#define O_SEQ_NUM_HEAD         (O_VC_ID_HEAD + W_VC_ID_HEAD)
#define O_RESERVED_HEAD        (O_SEQ_NUM_HEAD + W_SEQ_NUM_HEAD)

#define HEAD_FLIT_SIZE         FLIT_SIZE // equals 72

//                                  Body flit format (72 bits)
// 71               63                                                           0
// +----------------+------------------------------------------------------------+
// |    seq_num     |                          payload                           |
// +----------------+------------------------------------------------------------+
// |       8        |                             64                             |
// +----------------+------------------------------------------------------------+
// |      64        |                              0                             |

// --- Body/Tail Flit Widths ---
#define W_PAYLOAD_BODY         64
#define W_SEQ_NUM_BODY         8

// --- Body/Tail Flit Cumulative Offsets ---
#define O_PAYLOAD_BODY         0
#define O_SEQ_NUM_BODY         (O_PAYLOAD_BODY + W_PAYLOAD_BODY)

#define BODY_FLIT_SIZE         FLIT_SIZE // equals 72

std::bitset<HEAD_FLIT_SIZE> BinarizeFlit (gem5::ruby::garnet::flit*);

int HammingDistance (const std::bitset<HEAD_FLIT_SIZE>& , const std::bitset<HEAD_FLIT_SIZE>& );

std::vector<gem5::ruby::garnet::flit *> HammingDistanceSort (const std::vector<gem5::ruby::garnet::flit *>& );

double calculateSwitchingProb ( const std::vector<gem5::ruby::garnet::flit *>& );

int calculateSwitchingToggles( const std::vector<gem5::ruby::garnet::flit *>& f );

void populateFlitData(std::vector<gem5::ruby::garnet::flit *>& packet, gem5::ruby::MsgPtr msg_ptr);

void populateFlitData(std::vector<gem5::ruby::garnet::flit *>& packet);
}