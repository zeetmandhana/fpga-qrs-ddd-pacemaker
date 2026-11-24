`timescale 1ns/1ps
//============================================================================
// event_priority.v  --  P17: the event-priority / timer-expiry block
//
// Pure combinational arbiter extracted from the DDD controller. Inputs are the
// timer-expiry predicates and sense signals; outputs are the four device
// events in fixed priority VS > VP > AS > AP.
//
// The equations below are the two-level SOP produced by ESPRESSO from the
// professor's A2DSL Digital Logic Synthesis Kit (vl401.py twolevel, Berkeley
// espresso, run on Google Colab; confirmed minimal with --exact):
//   9 product terms (AND gates), 34 literals, down from 148 truth-table rows.
// Full log: results/stage6c_espresso_vl401_colab.txt. Checked equal to
// src/event_priority.py::decide on all 256 inputs (src/verify_espresso_kit.py)
// and in xsim by tb_event_priority.v. The kit's SIS script.rugged gives the
// 14-literal multi-level form  VP = VS'mpu, AS = VS'ab'p', AP = VS'AS'ep'.
//
//   p = phase==AVI   a = a_in        v = v_in       r = t_v>=VRP
//   m = t_av>=AVI    u = t_v>=URI    e = t_v>=AEI    b = t_v<PVARP (blanked)
//============================================================================
module event_priority (
    input  wire p, a, v, r, m, u, e, b,
    output wire vs,      // ventricular sense
    output wire vp,      // ventricular pace
    output wire as_o,    // atrial sense
    output wire ap       // atrial pace
);
    // espresso product terms (one AND gate each)
    wire t_vr    =  v &  r;                    // --11----  -> VS
    wire t_pvmu  =  p & ~v &  m &  u;          // 1-0-11--  -> VP
    wire t_prmu  =  p & ~r &  m &  u;          // 1--011--  -> VP
    wire t_pavb  = ~p &  a & ~v & ~b;          // 010----0  -> AS
    wire t_parb  = ~p &  a & ~r & ~b;          // 01-0---0  -> AS
    wire t_pave  = ~p & ~a & ~v &  e;          // 000---1-  -> AP
    wire t_pare  = ~p & ~a & ~r &  e;          // 00-0--1-  -> AP
    wire t_pveb  = ~p & ~v &  e &  b;          // 0-0---11  -> AP
    wire t_preb  = ~p & ~r &  e &  b;          // 0--0--11  -> AP

    // OR plane
    assign vs   = t_vr;
    assign vp   = t_pvmu | t_prmu;
    assign as_o = t_pavb | t_parb;
    assign ap   = t_pave | t_pare | t_pveb | t_preb;
endmodule
