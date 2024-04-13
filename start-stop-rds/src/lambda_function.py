import boto3

def lambda_handler(event, context):
    action = event.get('action')
    if action == 'stop':
        stop_rds_instances()
    elif action == 'start':
        start_rds_instances()

def stop_rds_instances():
    rds = boto3.client('rds')
    instances = get_instances_with_tag('schedule', 'true') # Get instances with tag 'schedule' set to 'true'
    
    for instance in instances:
        rds.stop_db_instance(DBInstanceIdentifier=instance)

def start_rds_instances():
    rds = boto3.client('rds')
    instances = get_instances_with_tag('schedule', 'true') # Get instances with tag 'schedule' set to 'true'
    
    for instance in instances:
        rds.start_db_instance(DBInstanceIdentifier=instance)

def get_instances_with_tag(tag_key, tag_value):
    ec2 = boto3.client('ec2')
    response = ec2.describe_instances(Filters=[{'Name': f'tag:{tag_key}', 'Values': [tag_value]}])
    instances = []
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instances.append(instance['InstanceId'])
    return instances
