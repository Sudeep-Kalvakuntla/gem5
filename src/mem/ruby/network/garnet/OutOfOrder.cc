#include "mem/ruby/network/garnet/OutOfOrder.hh"
#include "mem/ruby/network/garnet/flit.hh"

namespace gem5 {
namespace ruby {
namespace garnet {
    uint32_t
    gem5::ruby::garnet::flit::get_seq_num (){
        return (flit_bin >> O_SEQ_NUM_HEAD).to_ullong() & ((1<<W_SEQ_NUM_HEAD)-1);
    }

    void
    gem5::ruby::garnet::flit::set_seq_num (int seq){
        std::bitset<HEAD_FLIT_SIZE> seq_bits(seq);
        std::bitset<HEAD_FLIT_SIZE> mask_bits((1<<W_SEQ_NUM_HEAD)-1);

        seq_bits &= mask_bits;
        flit_bin |= seq_bits << O_SEQ_NUM_HEAD;
    }
}
}
}

namespace OOO {
//Namespace for out of order

std::bitset<HEAD_FLIT_SIZE> BinarizeFlit (gem5::ruby::garnet::flit* f) {

    std::bitset<HEAD_FLIT_SIZE> b(0);

    // Lambda to pack values into the flit based on their offset and width
    auto pack = [&](uint64_t val, int offset, int width) {
        std::bitset<HEAD_FLIT_SIZE> fieldBits(val & GET_MASK(width)); //Creates a mask based on the width and clears bits outside it
        b |= (fieldBits << offset); //Places the data in the required offset
    };

    if (f->get_type() == gem5::ruby::garnet::HEAD_ || f->get_type() == gem5::ruby::garnet::HEAD_TAIL_){
        
        pack(f->get_vc(),                  O_VC_ID_HEAD,          W_VC_ID_HEAD);
        pack(f->get_type(),                O_TYPE_HEAD,           W_TYPE_HEAD);
        pack(f->get_route().src_ni,        O_SRC_NI_HEAD,         W_SRC_NI_HEAD);
        pack(f->get_route().src_router,    O_SRC_ROUTER_HEAD,     W_SRC_ROUTER_HEAD);
        pack(f->get_route().dest_ni,       O_DEST_NI_HEAD,        W_DEST_NI_HEAD);
        pack(f->get_route().dest_router,   O_DEST_ROUTER_HEAD,    W_DEST_ROUTER_HEAD);
        pack(f->get_route().hops_traversed,O_HOPS_TRAVERSED_HEAD, W_HOPS_TRAVERSED_HEAD);
        pack(random(),                     O_PAYLOAD_HEAD,        W_PAYLOAD_HEAD);

        //TODO: Placing the payload into the flit after dereferencing it from messsage block
    }
    else if (f->get_type() == gem5::ruby::garnet::BODY_ || f->get_type() == gem5::ruby::garnet::TAIL_) {
        
        pack(f->get_vc(),   O_VC_ID_BODY, W_VC_ID_BODY);
        pack(f->get_type(), O_TYPE_BODY, W_TYPE_BODY);
        pack(random(),      O_PAYLOAD_HEAD, W_PAYLOAD_HEAD);

        //TODO: Placing the payload into the flit after dereferencing it from messsage block
    }

    return b;
}

int 
HammingDistance (const std::bitset<HEAD_FLIT_SIZE>& flit1, const std::bitset<HEAD_FLIT_SIZE>& flit2){
    return (flit1 ^ flit2).count();
}

std::vector<gem5::ruby::garnet::flit *> 
HammingDistanceSort (const std::vector<gem5::ruby::garnet::flit *>& unsorted_f ){
    int num_flits = unsorted_f.size();
    std::vector<gem5::ruby::garnet::flit *> sorted_f(num_flits);

    if (num_flits > 2){
        std::bitset<HEAD_FLIT_SIZE> prev_f = unsorted_f[0]->flit_bin;

        sorted_f[0] = unsorted_f[0];
        sorted_f[num_flits-1] = unsorted_f[num_flits-1];

        std::vector<bool> picked (num_flits, false);

        for (int i = 1; i < num_flits - 1; i++){
             int min_dist = HEAD_FLIT_SIZE+1;
             int best_idx = -1;

            for (int j = 1; j < num_flits - 1; j++){
                int dist = HammingDistance(prev_f, unsorted_f[j]->flit_bin);
                if (dist < min_dist && !picked[j]){
                    min_dist = dist;
                    best_idx = j;
                }
            }

            if (best_idx != -1){
                picked[best_idx] = true;
                sorted_f[i] = unsorted_f[best_idx];
                prev_f = sorted_f[i]->flit_bin;
            }
        }

        return sorted_f;
    }
    else {
        return unsorted_f;
    }
   
}

}