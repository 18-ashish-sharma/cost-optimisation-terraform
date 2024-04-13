import boto3

# Initialize the EC2 client
ec2_client = boto3.client('ec2')

def stop_instances(instance_ids):
    ec2_client.stop_instances(InstanceIds=instance_ids)

def start_instances(instance_ids):
    ec2_client.start_instances(InstanceIds=instance_ids)

def lambda_handler(event, context):
    try:
        # Get instance IDs with the specified tag
        instance_ids = get_instances_to_manage()
        
        # Extract function name from the event
        function_name = event['function_name']
        
        # Execute the appropriate function
        if function_name == 'stop_instances':
            stop_instances(instance_ids)
        elif function_name == 'start_instances':
            start_instances(instance_ids)
        else:
            print(f"Invalid function name: {function_name}")
    except Exception as e:
        print(f"An error occurred: {str(e)}")

def get_instances_to_manage():
    # Initialize an empty list to store instance IDs
    instance_ids = []
    
    # Describe instances with the specified tag
    response = ec2_client.describe_instances(Filters=[
        {
            'Name': 'tag:Schedule',
            'Values': ['true']
        }
    ])

    # Extract instance IDs from the response
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instance_ids.append(instance['InstanceId'])
    
    return instance_ids
