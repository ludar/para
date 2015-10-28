<?php

namespace para;

use para\Para;
use PhpAmqpLib\Message\AMQPMessage;

abstract class ParaWorker extends Para {

	public function __construct($uid, $host = 'localhost', $port = 5672, $user = 'guest', $pwd = 'guest', $vhost = '/') {
		parent::__construct($uid, $host, $port, $user, $pwd, $vhost);

		//setup a local queue for the 'control' exchange
		list($qName,, ) = $this->channel->queue_declare('', false, false, true, false);
		$this->channel->queue_bind($qName, $this->u('control'));

		//only assign 1 task per worker until it is done
		$this->channel->basic_qos(0, 1, false);

		//listen to the 'task' queue. task messages require ack confirmation (2nd bool=false)
		$this->channel->basic_consume($this->u('task'), '', false, false, false, false, array($this, 'taskMsgHandler'));

		//listen to the 'control' exchange
		$this->channel->basic_consume($qName, '', false, true, false, false, array($this, 'controlMsgHandler'));
	}

	//process messages from the 'task' queue
	public function taskMsgHandler($msg) {
		$o = $this->unpackMessage($msg->body);

		//process the task
		$o->data = $this->process($o->data);

		//First pass results to the master, next confirm success.
		//This way on fail we might do the same task more than once but no tasks are lost
		$this->channel->basic_publish(new AMQPMessage($this->packMessage($o)), '', $this->u('result'));
		$this->channel->basic_ack($msg->get('delivery_tag'));
	}

	//process messages from the 'control' queue
	public function controlMsgHandler($msg) {
		switch ($msg->body) {
			case 'quit':
				//unbind from all events = leave the message loop
				$this->unbindAll();
				break;
		}
	}

	//real work is done here
	abstract public function process($task);
}
