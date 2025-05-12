from typing import Dict, Any, Optional, List, Union
import json
import logging

logger = logging.getLogger(__name__)

def parse_command_output(output: str) -> Dict[str, Any]:
    """
    Parse command output from drono_control.sh script
    Attempt to extract JSON if present, otherwise return raw output
    """
    if not output:
        return {"message": "No output returned"}
    
    # Try to find JSON in output
    try:
        # Look for JSON data between markers or just try to parse the whole thing
        json_start = output.find('{')
        json_end = output.rfind('}')
        
        if json_start >= 0 and json_end > json_start:
            json_str = output[json_start:json_end+1]
            return json.loads(json_str)
        else:
            # Try the whole string
            return json.loads(output)
    except json.JSONDecodeError:
        # Not JSON, return as plain text
        return {"raw_output": output.strip()}
    except Exception as e:
        logger.error(f"Error parsing command output: {e}")
        return {"error": "Failed to parse output", "raw_output": output.strip()}

def format_error_response(status_code: int, detail: str) -> Dict[str, Any]:
    """Format a standard error response"""
    return {
        "status_code": status_code,
        "detail": detail,
        "type": "error"
    }

def format_success_response(data: Any = None, message: str = None) -> Dict[str, Any]:
    """Format a standard success response"""
    response = {
        "status": "success",
    }
    
    if data is not None:
        response["data"] = data
    
    if message is not None:
        response["message"] = message
    
    return response 