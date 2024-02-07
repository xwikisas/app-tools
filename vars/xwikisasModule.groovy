#!/usr/bin/env groovy

/*
 * See the NOTICE file distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA, or see the FSF site: http://www.fsf.org.
 */

def call(body)
{
    node {
        xwikiBuild('Paid App Build') {
            // Default configuration shared by all paid apps.
            dockerHubSecretId = 'xwikisasci'
            dockerHubUserId = 'xwikisasci'

            // Use the Maven version configured through the Jenkins UI rather than the version installed on the CI agent. Drop this when we move to Docker-based CI agents.
            mavenTool = 'Maven'
            mavenOpts = '-Xmx3076m -Xms512m -XX:MaxPermSize=768m'

            // Merge the application specific configuration.
            body.resolveStrategy = Closure.DELEGATE_FIRST
            body.delegate = delegate
            body()
        }
    }
}
