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

//                                  Head flit format
//  135      127      123      119      111      103       95       87       79        0
//       +---------+--------+--------+--------+--------+--------+--------+--------+--------+
// Field | seq_num | vc_id  |  type  | src_ni | src_rt | dst_ni | dst_rt |  hops  | payload|
//       +---------+--------+--------+--------+--------+--------+--------+--------+--------+
// Bits  |    8    |   4    |   4    |   8    |   8    |   8    |   8    |   8    |   80   |
//       +---------+--------+--------+--------+--------+--------+--------+--------+--------+
// Offset|   128   |  124   |  120   |  112   |  104   |   96   |   88   |   80   |    0   |

// --- Head Flit Widths ---
#define W_PAYLOAD_HEAD         80 
#define W_HOPS_TRAVERSED_HEAD  8
#define W_DEST_ROUTER_HEAD     8
#define W_DEST_NI_HEAD         8
#define W_SRC_ROUTER_HEAD      8
#define W_SRC_NI_HEAD          8
#define W_TYPE_HEAD            4
#define W_VC_ID_HEAD           4
#define W_SEQ_NUM_HEAD         8

// --- Head Flit Cumulative Offsets ---
#define O_PAYLOAD_HEAD         0
#define O_HOPS_TRAVERSED_HEAD  (O_PAYLOAD_HEAD + W_PAYLOAD_HEAD)
#define O_DEST_ROUTER_HEAD     (O_HOPS_TRAVERSED_HEAD + W_HOPS_TRAVERSED_HEAD)
#define O_DEST_NI_HEAD         (O_DEST_ROUTER_HEAD + W_DEST_ROUTER_HEAD)
#define O_SRC_ROUTER_HEAD      (O_DEST_NI_HEAD + W_DEST_NI_HEAD)
#define O_SRC_NI_HEAD          (O_SRC_ROUTER_HEAD + W_SRC_ROUTER_HEAD)
#define O_TYPE_HEAD            (O_SRC_NI_HEAD + W_SRC_NI_HEAD)
#define O_VC_ID_HEAD           (O_TYPE_HEAD + W_TYPE_HEAD)
#define O_SEQ_NUM_HEAD         (O_VC_ID_HEAD + W_VC_ID_HEAD)

#define HEAD_FLIT_SIZE         (W_SEQ_NUM_HEAD + O_SEQ_NUM_HEAD) //equals 136

//                                  Body flit format
// 136       127       123      119                             0
//       +---------+--------+--------+---------------------------------------------------+
// Field | seq_num | vc_id  |  type  |                      payload                      |
//       +---------+--------+--------+---------------------------------------------------+
// Bits  |    8    |   4    |   4    |                        120                        |
//       +---------+--------+--------+---------------------------------------------------+
// Offset|   128   |  124   |  120   |                         0                         |

// --- Body/Tail Flit Widths ---
#define W_PAYLOAD_BODY         120
#define W_TYPE_BODY            W_TYPE_HEAD
#define W_VC_ID_BODY           W_VC_ID_HEAD
#define W_SEQ_NUM_BODY         W_SEQ_NUM_HEAD

// --- Body/Tail Flit Cumulative Offsets ---
#define O_PAYLOAD_BODY         0
#define O_TYPE_BODY            (O_PAYLOAD_BODY + W_PAYLOAD_BODY)
#define O_VC_ID_BODY           (O_TYPE_BODY + W_TYPE_BODY)
#define O_SEQ_NUM_BODY         (O_VC_ID_BODY + W_VC_ID_BODY)

#define BODY_FLIT_SIZE         (O_VC_ID_BODY + W_VC_ID_BODY) // equals 136

std::bitset<HEAD_FLIT_SIZE> BinarizeFlit (gem5::ruby::garnet::flit*);

int HammingDistance (const std::bitset<HEAD_FLIT_SIZE>& , const std::bitset<HEAD_FLIT_SIZE>& );

std::vector<gem5::ruby::garnet::flit *> HammingDistanceSort (const std::vector<gem5::ruby::garnet::flit *>& );

double calculateSwitchingProb ( const std::vector<gem5::ruby::garnet::flit *>& );

void populateFlitData(std::vector<gem5::ruby::garnet::flit *>& packet, gem5::ruby::MsgPtr msg_ptr);
}