#include "mem/ruby/network/garnet/OutOfOrder.hh"
#include "mem/ruby/network/garnet/flit.hh"

#include "mem/ruby/system/RubySystem.hh"

// Ruby Message types
#include "mem/ruby/slicc_interface/Message.hh"
#include "mem/ruby/common/DataBlock.hh"

// Protocol specific generated headers 
// (Ensure you have built gem5 once for these to exist)
#include "mem/ruby/protocol/ResponseMsg.hh"
#include "mem/ruby/protocol/RequestMsg.hh"

namespace gem5 {
namespace ruby {
namespace garnet {
    uint32_t
    gem5::ruby::garnet::flit::get_seq_num (){
        return (this->flit_bin >> O_SEQ_NUM_HEAD).to_ullong() & ((1<<W_SEQ_NUM_HEAD)-1);
    }

    void
    gem5::ruby::garnet::flit::set_seq_num (int seq){
        std::bitset<HEAD_FLIT_SIZE> seq_bits(seq);
        std::bitset<HEAD_FLIT_SIZE> mask_bits((1<<W_SEQ_NUM_HEAD)-1);

        seq_bits &= mask_bits;
        this->flit_bin |= seq_bits << O_SEQ_NUM_HEAD;
    }

    std::bitset<HEAD_FLIT_SIZE>
    gem5::ruby::garnet::flit::get_payload() {
        int width = (m_type == HEAD_ || m_type == HEAD_TAIL_) ? W_PAYLOAD_HEAD : W_PAYLOAD_BODY;
        int offset = (m_type == HEAD_ || m_type == HEAD_TAIL_) ? O_PAYLOAD_HEAD : O_PAYLOAD_BODY;

        std::bitset<HEAD_FLIT_SIZE> mask;
        for (int i = 0; i < width; i++) mask.set(i + offset);

        // Isolate bits with mask, then shift right by 'offset' to normalize to bit 0
        return (this->flit_bin & mask) >> offset;
    }

    void
    gem5::ruby::garnet::flit::set_payload(std::bitset<HEAD_FLIT_SIZE> data) {
        int width = (m_type == HEAD_ || m_type == HEAD_TAIL_) ? W_PAYLOAD_HEAD : W_PAYLOAD_BODY;
        int offset = (m_type == HEAD_ || m_type == HEAD_TAIL_) ? O_PAYLOAD_HEAD : O_PAYLOAD_BODY;

        // Create a mask for the specific payload area in the 136-bit flit_bin
        std::bitset<HEAD_FLIT_SIZE> mask;
        for (int i = 0; i < width; i++) mask.set(i + offset);

        // Clear the payload bits, then OR in the new (shifted) data
        this->flit_bin &= ~mask;
        this->flit_bin |= (data << offset) & mask;
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
            pack(0,                     O_PAYLOAD_HEAD,        W_PAYLOAD_HEAD);

            //TODO: Placing the payload into the flit after dereferencing it from messsage block
        }
        else if (f->get_type() == gem5::ruby::garnet::BODY_ || f->get_type() == gem5::ruby::garnet::TAIL_) {

            pack(f->get_vc(),   O_VC_ID_BODY, W_VC_ID_BODY);
            pack(f->get_type(), O_TYPE_BODY, W_TYPE_BODY);
            pack(0,      O_PAYLOAD_HEAD, W_PAYLOAD_HEAD);

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

    double
    calculateSwitchingProb ( const std::vector<gem5::ruby::garnet::flit *>& f ){
        int f_size = f.size();
        if (f_size < 2) return 0.0;

        int total_switches = 0;
        int total_possible_switches = (f_size - 1) * HEAD_FLIT_SIZE;

        for (int i = 0; i < f_size-1; i++){
            total_switches += HammingDistance(f[i]->flit_bin, f[i+1]->flit_bin);
        }

        return (double)total_switches/total_possible_switches;
    }

    void
    populateFlitData(std::vector<gem5::ruby::garnet::flit *>& packet, 
                     gem5::ruby::MsgPtr msg_ptr)
    {
        // Access the base message
        const gem5::ruby::Message* r_msg = msg_ptr.get();
        if (!r_msg) return;

        gem5::ruby::DataBlock block;
        bool has_data = false;

        // Casting to protocol-specific types
        // Note: These generated classes are in the gem5::ruby namespace
        auto resp_msg = dynamic_cast<const gem5::ruby::ResponseMsg*>(r_msg);
        if (resp_msg) {
            block = resp_msg->getDataBlk();
            has_data = true;
        } else {
            auto req_msg = dynamic_cast<const gem5::ruby::RequestMsg*>(r_msg);
            if (req_msg) {
                block = req_msg->getDataBlk();
                has_data = true;
            }
        }

        if (!has_data) return;

        int current_byte_offset = 0;
        int total_bytes = gem5::ruby::RubySystem::getBlockSizeBytes();

        for (auto& fl : packet) {
            // Use gem5::ruby::garnet namespace for constants and types
            int width = (fl->get_type() == gem5::ruby::garnet::HEAD_ || 
                         fl->get_type() == gem5::ruby::garnet::HEAD_TAIL_) 
                        ? W_PAYLOAD_HEAD 
                        : W_PAYLOAD_BODY;

            std::bitset<HEAD_FLIT_SIZE> payload_to_pack;
            int bytes_to_read = width / 8;

            for (int b = 0; b < bytes_to_read && current_byte_offset < total_bytes; b++) {
                uint8_t byte_val = block.getByte(current_byte_offset);

                // Standard bitset packing
                std::bitset<HEAD_FLIT_SIZE> byte_bits(byte_val);
                payload_to_pack |= (byte_bits << (b * 8));

                current_byte_offset++;
            }

            // Apply data to the flit
            fl->set_payload(payload_to_pack);
        }
    } 
}