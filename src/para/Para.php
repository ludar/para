<?php

namespace para;

use PhpAmqpLib\Connection\AMQPStreamConnection;

class Para {

	protected $uid, $uidName, $channel;
	private $firstLoop;

	protected function u($s) {
		return $s . '.' . $this->uid;
	}

	public function raise($s, $method) {
		throw new \Exception($method . ' : ' . $s);
	}

	protected function log($s) {
		echo $s . "\n";
	}

	//@uidName must look like 'someName.someMD5Hash'
	public function __construct($uidName, $host, $port, $user, $pwd, $vhost) {
		$this->uidName = $uidName;
		$this->firstLoop = true;
		list(, $this->uid) = explode('.', $uidName, 2);

		$connection = new AMQPStreamConnection($host, $port, $user, $pwd, $vhost);
		$this->channel = $connection->channel();

		//4th bool = auto delete. DONT USE AUTODELETE!!
		$this->channel->queue_declare($this->u('task'), false, false, false, false);
		$this->channel->queue_declare($this->u('result'), false, false, false, false);
		//3rd bool states for auto delete. DONT USE AUTODELETE!!
		$this->channel->exchange_declare($this->u('control'), 'fanout', false, false, false);
	}

	public function __destruct() {
		$connection = $this->channel->getConnection();
		$this->channel->close();
		$connection->close();
	}

	public function loop($timeout = 0) {
		if ($this->firstLoop) {
			$this->firstLoop = false;
			//it can be used to check if the master process has succesfully started
			$this->log('started ' . $this->uidName);
		}

		while (count($this->channel->callbacks))
			$this->channel->wait(null, false, $timeout);
	}

	protected function unbindAll() {
		foreach (array_keys($this->channel->callbacks) as $k)
			$this->channel->basic_cancel($k);
	}

	protected function packMessage($o) {
		return json_encode($o);
	}

	protected function unpackMessage($s) {
		//NEVER EVER USE OBJECTS HERE!!
		//Decoding into arrays always produces arrays.
		//Decoding into objects produces objects and might produce 0-based arrays.
		//So decoding into objects produces mixed types.
		return json_decode($s, true);
	}

}
