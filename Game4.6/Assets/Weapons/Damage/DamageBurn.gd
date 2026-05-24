class_name DamageBurn extends DamageAttack

func kill_message():
	return "Player burned to death after being ignited by " + str(attacker)
