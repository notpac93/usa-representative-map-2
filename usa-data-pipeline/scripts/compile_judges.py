import csv
import json
import os

def parse_judges():
    input_file = '../assets/data/judges.csv'
    if not os.path.exists(input_file):
        print(f"File not found: {input_file}")
        return

    circuit_judges = {}
    district_judges = {}

    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # A judge can have up to 6 appointments
            for i in range(1, 7):
                court_type = row.get(f'Court Type ({i})', '').strip()
                court_name = row.get(f'Court Name ({i})', '').strip()
                termination = row.get(f'Termination ({i})', '').strip()
                title = row.get(f'Appointment Title ({i})', '').strip()
                
                if court_name and termination == "":
                    # Active judge
                    first_name = row.get('First Name', '').strip()
                    last_name = row.get('Last Name', '').strip()
                    middle_name = row.get('Middle Name', '').strip()
                    
                    name = f"{first_name} {middle_name} {last_name}".replace('  ', ' ').strip()
                    
                    judge_obj = {
                        "name": name,
                        "title": title,
                        "court": court_name,
                        "appointed_by": row.get(f'Appointing President ({i})', '').strip(),
                        "party": row.get(f'Party of Appointing President ({i})', '').strip(),
                    }
                    
                    if court_type == "U.S. Court of Appeals":
                        if court_name not in circuit_judges:
                            circuit_judges[court_name] = []
                        circuit_judges[court_name].append(judge_obj)
                    elif court_type == "U.S. District Court":
                        if court_name not in district_judges:
                            district_judges[court_name] = []
                        district_judges[court_name].append(judge_obj)

    # Save to json
    out_dir = '../assets/data'
    with open(os.path.join(out_dir, 'circuit_judges.json'), 'w') as f:
        json.dump(circuit_judges, f, indent=2)
        
    with open(os.path.join(out_dir, 'district_judges.json'), 'w') as f:
        json.dump(district_judges, f, indent=2)

    print(f"Compiled {sum(len(v) for v in circuit_judges.values())} Circuit Judges across {len(circuit_judges)} circuits.")
    print(f"Compiled {sum(len(v) for v in district_judges.values())} District Judges across {len(district_judges)} districts.")

if __name__ == '__main__':
    parse_judges()
