mtype = { invite, ack, tcp, bye, message_alice, message_bob};
chan	alice_to_proxy = [0] of { mtype };
chan	proxy_to_alice = [0] of { mtype };
chan	bob_to_proxy = [0] of { mtype };
chan	proxy_to_bob = [0] of { mtype };

chan alice_to_bob = [0] of { mtype };
chan bob_to_alice = [0] of { mtype };

active proctype Alice()
{
	do
		::alice_to_proxy!invite ->
			proxy_to_alice?100
			proxy_to_alice?180
			proxy_to_alice?200 ->
				alice_to_bob!ack
				goto data
	od
	
	data:
		do
			::alice_to_bob!message_alice ->
				bob_to_alice?ack
			::bob_to_alice?message_bob ->
				alice_to_bob!ack
			::alice_to_bob!bye ->
				bob_to_alice?200 ->
					break;
		od
}

active proctype Proxy()
{
	do
		::alice_to_proxy?invite ->
			proxy_to_bob!invite
			proxy_to_alice!100
		::bob_to_proxy?180 ->
			proxy_to_alice!180
		::bob_to_proxy?200 ->
			proxy_to_alice!200
	od
}

active proctype Bob()
{
	do
		::proxy_to_bob?invite ->
			bob_to_proxy!180
			bob_to_proxy!200
		::alice_to_bob?ack ->
			goto data
	od

	data:
		do
			::alice_to_bob?message_alice  ->
			bob_to_alice!ack
			::bob_to_alice!message_bob ->
				alice_to_bob?ack
			::alice_to_bob?bye ->
				bob_to_alice!200 ->
				break;
		od
}
