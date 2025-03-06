mtype = {REQUEST, RESPONSE, INVITE, FINISH, CANCEL, TRYING, RINGING, ACKNOWLEDGE, ERROR}

#define BUF_SIZE 1
#define ALICE_TO_PROXY 0
#define ALICE_TO_BOB 1
#define BOB_TO_PROXY 2
#define PROXY_TO_ALICE 3
#define BOB_TO_ALICE 4
#define PROXY_TO_BOB 5

chan client2server[6] = [BUF_SIZE] of {mtype};
chan server2client[6] = [BUF_SIZE] of {mtype};
chan server2net[6] = [BUF_SIZE] of {mtype, mtype, bit};
chan net2server[6] = [BUF_SIZE] of {mtype, mtype, bit};

proctype userA() {
   client2server[ALICE_TO_PROXY]!INVITE;
   do
   :: server2client[ALICE_TO_PROXY]?TRYING
   :: server2client[ALICE_TO_PROXY]?RINGING
   :: server2client[ALICE_TO_PROXY]?ACKNOWLEDGE -> client2server[ALICE_TO_BOB]!RESPONSE; break
   :: server2client[ALICE_TO_PROXY]?CANCEL -> goto finish
   :: server2client[ALICE_TO_PROXY]?ERROR -> goto finish
   od;
   client2server[ALICE_TO_BOB]!FINISH;
   server2client[ALICE_TO_BOB]?ACKNOWLEDGE;

finish:
   skip
}

proctype middleman() {
finish:
   do
   :: server2client[PROXY_TO_ALICE]?INVITE ->
      client2server[PROXY_TO_ALICE]!TRYING;
      if
      :: client2server[PROXY_TO_BOB]!INVITE
      :: client2server[PROXY_TO_ALICE]!ERROR
      fi
   :: server2client[PROXY_TO_BOB]?RINGING -> client2server[PROXY_TO_ALICE]!RINGING
   :: server2client[PROXY_TO_BOB]?ACKNOWLEDGE -> client2server[PROXY_TO_ALICE]!ACKNOWLEDGE
   :: server2client[PROXY_TO_BOB]?CANCEL -> client2server[PROXY_TO_ALICE]!CANCEL
   od
}

proctype userB() {
awaiting_invite:
   server2client[BOB_TO_PROXY]?INVITE;
   client2server[BOB_TO_PROXY]!RINGING;
   if
   :: client2server[BOB_TO_PROXY]!ACKNOWLEDGE -> skip
   :: client2server[BOB_TO_PROXY]!CANCEL -> goto finish
   fi;
   server2client[BOB_TO_ALICE]?RESPONSE;
   server2client[BOB_TO_ALICE]?FINISH;
   client2server[BOB_TO_ALICE]!ACKNOWLEDGE;

finish:
   skip
}

proctype sender(byte identifier) {
   mtype signal;
   bit b, state;

finish:
   client2server[identifier]?signal;

retry:
   server2net[identifier]!REQUEST, signal, state;
   if
   :: net2server[identifier]?RESPONSE, _, b ->
      if
      :: b == state -> state = 1 - state; goto finish
      :: b != state -> goto retry
      fi
   :: timeout -> goto retry
   fi
}

proctype receiver(byte identifier) {
   mtype signal;
   bit b, rcvd;

finish:
   do
   :: net2server[identifier]?REQUEST, signal, b;
      server2net[identifier]!RESPONSE, 0, b;
      if
      :: b == rcvd -> rcvd = 1 - rcvd; server2client[identifier]!signal
      :: b != rcvd -> skip
      fi
   od
}

proctype network() {
   mtype s_msg, sig;
   bit recv_flag;

finish:
   do
   :: server2net[ALICE_TO_PROXY]?s_msg, sig, recv_flag ->
      if
      :: net2server[PROXY_TO_ALICE]!s_msg, sig, recv_flag
      :: skip
      fi
   :: server2net[ALICE_TO_BOB]?s_msg, sig, recv_flag ->
      if
      :: net2server[BOB_TO_ALICE]!s_msg, sig, recv_flag
      :: skip
      fi
   :: server2net[PROXY_TO_ALICE]?s_msg, sig, recv_flag ->
      if
      :: net2server[ALICE_TO_PROXY]!s_msg, sig, recv_flag
      :: skip
      fi
   :: server2net[PROXY_TO_BOB]?s_msg, sig, recv_flag ->
      if
      :: net2server[BOB_TO_PROXY]!s_msg, sig, recv_flag
      :: skip
      fi
   :: server2net[BOB_TO_ALICE]?s_msg, sig, recv_flag ->
      if
      :: net2server[ALICE_TO_BOB]!s_msg, sig, recv_flag
      :: skip
      fi
   :: server2net[BOB_TO_PROXY]?s_msg, sig, recv_flag ->
      if
      :: net2server[PROXY_TO_BOB]!s_msg, sig, recv_flag
      :: skip
      fi
   od
}

init {
   run network();
   run sender(ALICE_TO_PROXY);
   run receiver(ALICE_TO_PROXY);
   run sender(ALICE_TO_BOB);
   run receiver(ALICE_TO_BOB);
   run sender(PROXY_TO_ALICE);
   run receiver(PROXY_TO_ALICE);
   run sender(PROXY_TO_BOB);
   run receiver(PROXY_TO_BOB);
   run sender(BOB_TO_ALICE);
   run receiver(BOB_TO_ALICE);
   run sender(BOB_TO_PROXY);
   run receiver(BOB_TO_PROXY);
   

   run userA();
   run middleman();
   run userB();
}
