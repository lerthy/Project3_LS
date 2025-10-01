# Assignment: 
## Apply AWS Well-Architected Framework (WAF) Pillars to your "DevOps CI/CD" project

---

## Objective
Analyze your previous **DevOps CI/CD project** through the lens of the **six AWS Well-Architected pillars** 
and back up your analysis with **Terraform (TF) changes** that implement or improve your design.

---

## What You Will Produce
1. A **Markdown report** with your analysis and decisions per pillar.  
2. A working **Terraform** that demonstrates key improvements across all pillars for your CI/CD and Application stacks.  

---

## Instructions
1. **Baseline:** Briefly describe your existing setup (tools, repos, target environment, runtime). 15 sentences max.  
2. **Per pillar:** Fill the sections below:  
   - Current state  
   - Gaps  
   - TF improvements  
   - Evidence  
3. **Terraform:** Implement TF and adapt to your project (providers, names, tags). You may add, change or remove resources.  
4. **Validation:** Run:  

 - You are encouraged to use the **AWS Well-Architected Framework checklist** for each pillar.  
    - For each question in the checklist, note whether your project addresses it.  
    - If it does, show evidence (TF code, logs, screenshots).  
    - If not, propose an improvement and show how you could implement it with TF.  

----

Sample: 
###  1) Operational Excellence
   - **Current:** How do you run, observe, and evolve the pipeline?  
   - **Gaps:** Missing runbooks? No alarms? Manual steps?  
   - **TF Improvements:** e.g., CloudWatch log groups with retention, alarms on failed builds/deploys, structured tags, IaC for CodePipeline/CodeBuild/roles.  
   - **Evidence:** Links/line references to TF resources; logs etc.  

---

## Scoring

Each pillar will contribute to your assessment as follows:

- **Operational Excellence** – 20%  
- **Security** – 20%  
- **Reliability** – 20%  
- **Performance Efficiency** – 20%  
- **Cost Optimization** – 10%  
- **Sustainability** – 10%  
