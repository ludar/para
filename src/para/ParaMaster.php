<?php

namespace para;

use para\Para;
use PhpAmqpLib\Message\AMQPMessage;
use PhpAmqpLib\Exception\AMQPTimeoutException;

abstract class ParaMaster extends Para {

	protected $tasksToPrefetch, $tasksToProcess, $finalizing, $processId;

	public function __construct($uid, $tasksToPrefetch, $host = 'localhost', $port = 5672, $user = 'guest', $pwd = 'guest', $vhost = '/') {
		//Read the method declaration below
		$this->setup();

		parent::__construct($uid, $host, $port, $user, $pwd, $vhost);

		$this->tasksToPrefetch = $tasksToPrefetch;
		$this->tasksToProcess = 0;
		$this->finalizing = false;

		//This is used to distinguish results from previous master incarnations.
		//Tagging results is vital to calculate @tasksToProcess correctly.
		$this->processId = md5(microtime() . getmypid());

		//Clean the 'task' queue. There might be some in case of unclean master restarts.
		//Cleaning is done to lessen double execution occasions. It can't eliminate them completely
		$this->channel->queue_purge($this->u('task'));

		//only prefetch one result until ack.
		//It is not only important to not lose results on fail. The messages might be quite big (e.g. base64-ed images)
		//so prefetching some more results might hit the memory_limit
		$this->channel->basic_qos(0, 1, false);

		//Listen to the 'result' queue. Messages require ack confirmation (2nd bool=false)
		$this->channel->basic_consume($this->u('result'), '', false, false, false, false, array($this, 'resultMsgHandler'));

		//Fetch all available results. On unclean master restarts there might be ready to use results from workers.
		//It is done with 1-sec timeout wait(). On timeout an exception is raised effectively breaking the loop
		try {
			parent::loop(1);
		} catch (AMQPTimeoutException $e) {
			
		}
	}

	protected function quit( $reason='no more tasks. quitting') {
		$this->log($reason);
		//shut the workers down
		$this->channel->basic_publish(new AMQPMessage('quit'), $this->u('control'));
		//unbind from all events = leave the message loop
		$this->unbindAll();
	}

	public function loop($timeout = 0) {
		//feed first set of tasks
		if (!$this->registerTasks($this->getTasks($this->tasksToPrefetch))) {
			$this->quit();
			return;
		}

		parent::loop($timeout);
	}

	//Publish tasks to the 'task' queue.
	//Returns number tasks registered
	protected function registerTasks($tasks) {
		//turn on finalizing mode if the set of tasks is smaller than expected (i.e. no more tasks)
		if (($n = count($tasks)) < $this->tasksToPrefetch)
			$this->finalizing = true;

		foreach ($tasks as $k => $v) {
			$this->channel->basic_publish(new AMQPMessage($this->packMessage([
								'pid' => $this->processId,
								'key' => $k,
								'data' => $v
							])), '', $this->u('task'));
		}

		$this->tasksToProcess += $n;

		return $n;
	}

	//process messages from the 'result' queue
	public function resultMsgHandler($msg) {
		$o = $this->unpackMessage($msg->body);

		//process result and send ack.
		//The order is important: this way we never lose results but it might process the same result more than once (on fail)
		$this->process($o);
		$this->channel->basic_ack($msg->get('delivery_tag'));

		//Check for reminder. Only do it for own results!!
		if ($o['pid'] === $this->processId) {
			if (!--$this->tasksToProcess) {
				$this->quit();
			} elseif (!$this->finalizing && ($this->tasksToProcess / $this->tasksToPrefetch < 0.2)) {
				//fetch new set of tasks if the buffer falls below 20%
				//Be sure to have @tasksToPrefetch > 20% of total workers number so no workers are idle at any time
				$this->registerTasks($this->getTasks($this->tasksToPrefetch));
			}
		}
	}

	//it should return an array taskKey=>taskData of @n length at most.
	//taskKeys must be unique across the complete set of tasks!!
	//it should track previously passes tasks internally so each time it returns COMPLETELY another set
	abstract protected function getTasks($n);

	//real work is done here. @o has both @key (original) and @data (result) props
	abstract protected function process($o);

	//Optionally override it to do preliminary stuff like setting up a db connection etc.
	//It is called as the first line of the constructor
	protected function setup() {
		
	}

}
