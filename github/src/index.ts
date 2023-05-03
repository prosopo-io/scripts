import { Octokit } from 'octokit'
import dotenv from 'dotenv'

dotenv.config()

class OctokitWrapper {
    private octokit: Octokit
    constructor(private owner: string, private accessToken: string) {
        this.octokit = new Octokit({ auth: accessToken })
        this.owner = owner
    }

    public async getRepoLabels(repo: string) {
        const { data } = await this.octokit.request(`GET /repos/${this.owner}/${repo}/labels`, {
            owner: this.owner,
            repo,
        })
        return data
    }

    public async copyRepoLabels(originalRepo: string, newRepo: string) {
        const labels = await this.getRepoLabels(originalRepo)
        for (const label of labels) {
            try {
                await this.delRepoLabel(newRepo, label.name)
            } catch (e) {
                console.log(e)
            }
            await this.setRepoLabel(newRepo, label.name, label.color)
        }
    }

    public async setRepoLabel(repo: string, label: string, color: string) {
        const { data } = await this.octokit.request(`POST /repos/${this.owner}/${repo}/labels`, {
            owner: this.owner,
            repo,
            name: label,
            color,
        })
        return data
    }

    public async delRepoLabel(repo: string, label: string) {
        console.log(label)
        const { data } = await this.octokit.request(
            `DELETE /repos/${this.owner}/${repo}/labels/${urlEncodeString(label)}`
        )
        return data
    }
}

function urlEncodeString(str: string) {
    return str.replace(/\s/g, '%20')
}

function run() {
    if (!process.env.GITHUB_TOKEN) {
        throw new Error('No GITHUB_TOKEN env variable set')
    }
    const octokit = new OctokitWrapper('prosopo', process.env.GITHUB_TOKEN)
    octokit
        .copyRepoLabels('contract', 'captcha')
        .then(() => {
            console.log('done')
            process.exit(0)
        })
        .catch((err) => {
            console.error(err)
            process.exit(1)
        })
}

run()
