module dlangide.tools.d.dcdinterface;

import dlangui.core.logger;
import dlangui.core.files;

import dlangide.builders.extprocess;

import std.typecons;
import std.conv;
import std.string;

enum DCDResult : int {
	DCD_NOT_RUNNING = 0,
	SUCCESS,
	NO_RESULT,
	FAIL,
}
alias ResultSet = Tuple!(DCDResult, "result", dstring[], "output");

//Interface to DCD
//TODO: Check if server is running, start server if needed etc.
class DCDInterface {
	ExternalProcess dcdProcess;
	ProtectedTextStorage stdoutTarget;
	this() {
		dcdProcess = new ExternalProcess();
		stdoutTarget = new ProtectedTextStorage();
	}

    protected dstring[] invokeDcd(char[][] arguments, dstring content, out bool success) {
        success = false;
		ExternalProcess dcdProcess = new ExternalProcess();

		ProtectedTextStorage stdoutTarget = new ProtectedTextStorage();

		version(Windows) {
			string dcd_client_name = "dcd-client.exe";
			string dcd_client_dir = null;
		} else {
			string dcd_client_name = "dcd-client";
			string dcd_client_dir = "/usr/bin";
		}
		dcdProcess.run(dcd_client_name.dup, arguments, dcd_client_dir ? dcd_client_dir.dup : null, stdoutTarget);
		dcdProcess.write(content);
		dcdProcess.wait();

		dstring[] output =  stdoutTarget.readText.splitLines();

		if(dcdProcess.poll() == ExternalProcessState.Stopped) {
			success = true;
		}
        return output;
    }

	ResultSet goToDefinition(in dstring content, int index) {
		ResultSet result;

		char[][] arguments = ["-l".dup, "-c".dup];
		arguments ~= [to!(char[])(index)];

        bool success = false;
		dstring[] output =  invokeDcd(arguments, content, success);

		if (success) {
			result.result = DCDResult.SUCCESS;
		} else {
			result.result = DCDResult.FAIL;
			return result;
		}

        debug(DCD) Log.d("DCD output:\n", output);

		if(output.length > 0) {
			if(output[0].indexOf("Not Found".dup) == 0) {
				result.result = DCDResult.NO_RESULT;
				return result;
			}
		}

		auto split = output[0].indexOf("\t");
        if(split == -1) {
        	Log.d("DCD output format error.");
        	result.result = DCDResult.FAIL;
        	return result;
        }

        result.output ~= output[0][0 .. split];
        result.output ~= output[0][split+1 .. $];
		return result;
	}

	ResultSet getCompletions(in dstring content, int index) {

		ResultSet result;

		char[][] arguments = ["-c".dup];
		arguments ~= [to!(char[])(index)];

        bool success = false;
		dstring[] output =  invokeDcd(arguments, content, success);

		if (success) {
			result.result = DCDResult.SUCCESS;
		} else {
			result.result = DCDResult.FAIL;
			return result;
		}
        debug(DCD) Log.d("DCD output:\n", output);

		if (output.length == 0) {
			result.result = DCDResult.NO_RESULT;
			return result;
		}

		enum State : int {None = 0, Identifiers, Calltips}
		State state = State.None;
		foreach(dstring outputLine ; output) {
			if(outputLine == "identifiers") {
				state = State.Identifiers;
			}
			else if(outputLine == "calltips") {
				state = State.Calltips;
			}
			else {
				auto split = outputLine.indexOf("\t");
				if(split < 0) {
					break;
				}
				if(state == State.Identifiers) {
					result.output ~= outputLine[0 .. split];
				}
			}
		}
		return result;
	}
}
