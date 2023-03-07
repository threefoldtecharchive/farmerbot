# Testing the farmerbot
We highly recommend to write proper tests that cover most of the code in this repository. This document will teach you how to. 

## Running the existing tests
The tests have to be run before landing any PR. You can run the existing tests by running the command below:
> bash tests/run_tests.v

Or if you wish to run the tests for a specific manager:
> v -stats test tests/nodemanager_test.v

You can also filter the tests like so:
> v -stats test tests/nodemanager_test.v -run-only \<PATTERN\>

V supports running tests in parallel (running multiple test files in parallel actually) but unfortunately we cannot use it as the redis usage is meant to be single threaded.

## Good practices for writing tests
It is a good practice to structure a test in 3 parts: prepare, act and assert.

The preparation part usually contains the logic to mock things, to move the SUT in a secific state. The example below is manipulating the database so that we are able to test a specific path in the code.

The act part should only contain a couple of method calls which start the execution of the code that you are testing. In the example below we are testing the nodemanager's method find_node.

Finally, the assert part contains the code to make sure that the SUT is in a state that you expect it to be in after the test. We could expect the job farmerbot.nodemanager.findnode to return the node id 5 as shown in the test below.

Structuring tests with these 3 parts will result in tests that easy to read, that will only test one specific thing and that are easy to maintain.

```
fn test_find_node_that_is_on_first() {
	mut testenvironment := TestEnvironment{}
	testenvironment.run(fn (mut farmerbot Farmerbot, mut client Client) ! {
		// prepare
		farmerbot.db.nodes[3].powerstate = .off
		mut args := Params {}
		// can fit on node with id 3 but it is offline so use 5
		add_required_resources(mut args, "500GB", "100GB", "4GB", "2")

		// act
		mut job := client.job_new_wait(
			twinid: 162
			action: system.job_node_find
			args: args
			actionsource: ""
		) or {
			return error("failed to create and wait for job")
		}

		//assert
		ensure_no_error(&job)!
		ensure_result_contains_u32(&job, "nodeid", 5)!
	})!
}
```

## Adding tests
You can add new tests by following these steps:
1) make sure to go through existing tests before adding a new one, we don't want two tests that are testing the same thing
2) create a function with the same function definition as prior example
3) implement the test following the rules mentioned above (but with your custom logic)
```

