/*
 * Copyright (C) 2008,2010 Nokia Corporation.
 * Copyright (C) 2012 Intel Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

/**
 * This is the base class for every Rygel implementation of a UPnP media
 * server. It should be used either for a real plug-in for the Rygel process or used
 * in-process via the librygel-server API.
 *
 * The plugin instance should have a #RygelMediaContainer instance as its
 * root container, which may be provided to the constructor.
 *
 * See the
 * <link linkend="implementing-server-plugins">Implementing Server Plugins</link> section.
 */
public abstract class Rygel.MediaServerPlugin : Rygel.Plugin {
    private static const string DMS = "urn:schemas-upnp-org:device:MediaServer";
    private static const string MEDIA_SERVER_DESC_PATH =
                                BuildConfig.DATA_DIR + "/xml/MediaServer3.xml";

    public MediaContainer root_container { get; construct; }

    /**
     * Create an instance of the plugin.
     * The plugin's service will have the same title as its root container.
     *
     * @param root_container The container that should be served by this plugin's service.
     * @param name The non-human-readable name for the plugin and its service, used in UPnP messages and in the Rygel configuration file.
     * @param description An optional human-readable description (modelDescription) of the UPnP service provided by the plugin.
     */
    public MediaServerPlugin (MediaContainer root_container,
                              string         name,
                              string?        description = null,
                              PluginCapabilities capabilities =
                                        PluginCapabilities.NONE) {
        Object (desc_path : MEDIA_SERVER_DESC_PATH,
                name : name,
                title : root_container.title,
                description : description,
                capabilities : capabilities,
                root_container : root_container);
    }

    public override void constructed () {
        base.constructed ();

        var path = ContentDirectory.DESCRIPTION_PATH_NO_TRACK;

        // MediaServer implementations must implement ContentDirectory service
        if (PluginCapabilities.TRACK_CHANGES in this.capabilities) {
            path = ContentDirectory.DESCRIPTION_PATH;
        }

        var info = new ResourceInfo (ContentDirectory.UPNP_ID,
                                     ContentDirectory.UPNP_TYPE,
                                     path,
                                     typeof (ContentDirectory));
        this.add_resource (info);

        // Register Rygel.ConnectionManager
        info = new ResourceInfo (ConnectionManager.UPNP_ID,
                                 ConnectionManager.UPNP_TYPE,
                                 ConnectionManager.DESCRIPTION_PATH,
                                 typeof (SourceConnectionManager));

        this.add_resource (info);
        info = new ResourceInfo (MediaReceiverRegistrar.UPNP_ID,
                                 MediaReceiverRegistrar.UPNP_TYPE,
                                 MediaReceiverRegistrar.DESCRIPTION_PATH,
                                 typeof (MediaReceiverRegistrar));
        this.add_resource (info);

        if (root_container.child_count == 0) {
            debug ("Deactivating plugin '%s' until it provides content.",
                   this.name);

            this.active = false;

            root_container.container_updated.connect
                                        (this.on_container_updated);
        }
    }

    // TODO: Document this, or make it unnecessary.
    public override void apply_hacks (RootDevice device,
                                     string     description_path)
                                     throws Error {
        // Apply V1 downgrades
        string[] services = { ContentDirectory.UPNP_TYPE,
                              ConnectionManager.UPNP_TYPE };
        var v1_hacks = new V1Hacks (DMS, services);
        v1_hacks.apply_on_device (device, description_path);

        // Apply XBox hacks on top of that
        var xbox_hacks = new XBoxHacks ();
        xbox_hacks.apply_on_device (device, v1_hacks.description_path);
    }

    private void on_container_updated (MediaContainer root_container,
                                       MediaContainer updated,
                                       MediaObject object,
                                       ObjectEventType event_type,
                                       bool sub_tree_update) {
        if (updated != root_container || updated.child_count == 0) {
            return;
        }

        root_container.container_updated.disconnect
                                        (this.on_container_updated);

        debug ("Activating plugin '%s' since it now provides content.",
               this.name);

        this.active = true;
    }
}
