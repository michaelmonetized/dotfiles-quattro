#!/usr/bin/env python3
"""Read-only ghrepos enrichment. Credentials stay with the gh/vc CLIs."""
import concurrent.futures, datetime, fcntl, json, os, pathlib, subprocess, sys, time, urllib.parse
CACHE = pathlib.Path(os.environ.get('XDG_CACHE_HOME', pathlib.Path.home()/'.cache'))/'ghrepos-panel'
CACHE.mkdir(parents=True, exist_ok=True)
STATE = CACHE/'repos.json'

def run(argv, timeout=60):
    p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    if p.returncode:
        # CLI errors can include sensitive URLs; retain only a useful category.
        err = p.stderr.lower()
        kind = 'rate limited' if 'rate limit' in err else 'authentication required' if any(x in err for x in ['401', 'authentication', 'login']) else 'request failed'
        raise RuntimeError(f'{argv[0]} {kind} (exit {p.returncode})')
    return json.loads(p.stdout)

def gh(endpoint): return run(['gh', 'api', endpoint])
def cached():
    try: return json.loads(STATE.read_text())
    except (OSError, ValueError): return {'repos': [], 'updatedAt': 0, 'error': ''}
def emit(data): print(json.dumps(data, separators=(',', ':')), flush=True)
def save(data):
    tmp = STATE.with_suffix('.tmp')
    tmp.write_text(json.dumps(data)); tmp.chmod(0o600); tmp.replace(STATE)
def tone(state):
    s = (state or '').lower()
    if s in ('ready', 'success'): return 'success'
    if s in ('building','initializing','queued','pending','in_progress','waiting','requested'): return 'running'
    if s in ('error','failure','failed','timed_out','startup_failure','action_required'): return 'failed'
    return 'neutral'

def enrich(repo):
    r = dict(repo); owner = r['owner']['login']; slug = owner+'/'+r['name']; errors=[]
    r.update(ownerName=owner, avatar='https://github.com/'+urllib.parse.quote(owner)+'.png?size=64', comments=None,
             commitDate=None, commitUrl='', actions={'state':'unknown','tone':'neutral','url':r['url']+'/actions'}, deployments=[])
    def attempt(label, fn):
        try: return fn()
        except Exception as e: errors.append(label+': '+str(e)); return None
    query = '''query($owner:String!,$name:String!){repository(owner:$owner,name:$name){owner{avatarUrl} defaultBranchRef{target{... on Commit{committedDate url}}}}}'''
    meta=attempt('Commit', lambda:run(['gh','api','graphql','-f','query='+query,'-f','owner='+owner,'-f','name='+r['name']]))
    if meta:
        m=(meta.get('data') or {}).get('repository')
        if m:
            r['avatar']=m['owner']['avatarUrl']; c=(m.get('defaultBranchRef') or {}).get('target') or {}
            r['commitDate']=c.get('committedDate'); r['commitUrl']=c.get('url','')
        else: errors.append('Commit: repository unavailable')
    def comments():
        total=0; count=0; page=1
        while True:
            prs=gh(f'repos/{slug}/pulls?state=open&per_page=100&page={page}')
            for pr in prs:
                detail=gh(f'repos/{slug}/pulls/{pr["number"]}')
                total+=detail['comments']+detail['review_comments']; count+=1
            if len(prs)<100: break
            page+=1
        return total,count
    if r.get('pullRequests',0):
        c=attempt('PR comments', comments)
        if c is not None: r['comments'],r['pullRequests']=c
    else: r['comments']=0
    a=attempt('Actions',lambda:gh(f'repos/{slug}/actions/runs?per_page=1'))
    if a is not None:
        runs=a.get('workflow_runs',[])
        if runs:
            a=runs[0]; state=a.get('conclusion') if a['status']=='completed' else a['status']
            r['actions']={'state':state or 'unknown','tone':tone(state),'url':a['html_url'],'name':a.get('name','Actions'),'date':a['created_at']}
            if tone(state)=='success':
                r['actions']['url']=''
            elif tone(state)=='failed':
                r['actions']['url']=''
                r['actions']['logNote']='No failed Blacksmith job log available'
                def failed_jobs():
                    jobs=[]; page=1
                    while True:
                        batch=gh(f'repos/{slug}/actions/runs/{a["id"]}/jobs?per_page=100&page={page}').get('jobs',[])
                        jobs.extend(batch)
                        if len(batch)<100: return jobs
                        page+=1
                jobs=attempt('Blacksmith logs',failed_jobs)
                if jobs is not None:
                    failed=[j for j in jobs if tone(j.get('conclusion'))=='failed' and any('blacksmith' in str(label).lower() for label in j.get('labels',[]))]
                    if failed:
                        job=failed[0]
                        r['actions']['url']=f'https://app.blacksmith.sh/{urllib.parse.quote(owner,safe="")}/runs/{a["id"]}/jobs/{job["id"]}'
                        r['actions']['logNote']='Open Blacksmith log · '+job.get('name','failed job')
        else: r['actions']['state']='no runs'
    for project in r.get('vercel',[]):
        # ghrepos has a name-only fallback. Reject cross-owner collisions.
        link=project.get('link') or {}
        if str(link.get('repoId'))!=str(r['databaseId']) and (link.get('org','').lower()!=owner.lower() or link.get('repo')!=r['name']): continue
        endpoint='/v6/deployments?'+urllib.parse.urlencode({'projectId':project['id'],'target':'production','limit':1})
        d=attempt('Vercel '+project['name'],lambda:run(['vc','api',endpoint]))
        dep={'name':project['name'],'state':'unknown','tone':'neutral','url':'https://vercel.com/dashboard','site':(project.get('production') or {}).get('url','')}
        if d is not None:
            items=d.get('deployments',[])
            if items:
                v=items[0]; state=v.get('readyState') or v.get('state','unknown')
                build_url='https://'+v['url']+'/_logs' if v.get('url') else v.get('inspectorUrl','')
                dep.update(state=state,tone=tone(state),buildLogUrl=build_url,
                           url=(dep['site'] if tone(state)=='success' else build_url))
            else: dep['state']='no deployments'
        r['deployments'].append(dep)
    r['errors']=errors; r['checkedAt']=int(time.time()); return r

def main():
    old=cached()
    if '--cached' in sys.argv: emit(old); return
    with (CACHE/'refresh.lock').open('w') as lock:
        try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError: emit(old); return
        if '--force' not in sys.argv and time.time()-old.get('updatedAt',0)<300:
            emit(old); return
        try:
            repos=run(['ghrepos'],180)
            if not isinstance(repos,list): raise ValueError('ghrepos must output an array')
        except Exception as e:
            old['error']='Refresh failed: '+str(e); emit(old); return
        previous={r['url']:r for r in old['repos']}
        data={'repos':[previous.get(r['url'],dict(r,ownerName=r['owner']['login'],avatar='',comments=None,commitDate=None,commitUrl='',actions={'state':'loading','tone':'neutral','url':r['url']+'/actions'},deployments=[],errors=[])) for r in repos], 'updatedAt':old.get('updatedAt',0),'error':'','refreshing':True}
        emit(data)
        indexes={r['url']:i for i,r in enumerate(repos)}
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            futures={pool.submit(enrich,r):r for r in repos}
            last=0
            for f in concurrent.futures.as_completed(futures):
                r=futures[f]
                try: data['repos'][indexes[r['url']]]=f.result()
                except Exception as e: data['repos'][indexes[r['url']]]['errors']=['Refresh: '+str(e)]
                if time.monotonic()-last>1: emit(data); last=time.monotonic()
        data.update(updatedAt=int(time.time()),refreshing=False)
        save(data); emit(data)
if __name__=='__main__': main()
